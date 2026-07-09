import http from 'node:http'
import { randomUUID } from 'node:crypto'

const port = Number(process.env.CODEX_DEEPSEEK_PROXY_PORT || '8783')
const apiKey = process.env.DEEPSEEK_API_KEY

if (!apiKey) {
  console.error('Codex DeepSeek proxy requires DEEPSEEK_API_KEY')
  process.exit(1)
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' })
      res.end(JSON.stringify({ ok: true }))
      return
    }

    if (req.method !== 'POST' || !req.url?.startsWith('/v1/responses')) {
      res.writeHead(404, { 'content-type': 'application/json' })
      res.end(JSON.stringify({ error: { message: 'not found' } }))
      return
    }

    const body = await readJson(req)
    const deepseekResponse = await fetch('https://api.deepseek.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify(toChatCompletion(body))
    })

    if (!deepseekResponse.ok) {
      const text = await deepseekResponse.text()
      res.writeHead(deepseekResponse.status, { 'content-type': 'application/json' })
      res.end(text)
      return
    }

    const chat = await deepseekResponse.json()
    writeResponsesEventStream(res, chat)
  } catch (error) {
    res.writeHead(500, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: { message: error instanceof Error ? error.message : String(error) } }))
  }
})

server.listen(port, '127.0.0.1', () => {
  console.error(`codex-deepseek-responses-proxy listening on ${port}`)
})

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = ''
    req.on('data', chunk => {
      body += chunk
    })
    req.on('end', () => {
      try {
        resolve(JSON.parse(body || '{}'))
      } catch (error) {
        reject(error)
      }
    })
    req.on('error', reject)
  })
}

function toChatCompletion(request) {
  return {
    model: request.model || 'deepseek-chat',
    messages: toChatMessages(request.input || []),
    tools: toChatTools(request.tools || []),
    tool_choice: request.tool_choice || 'auto',
    stream: false
  }
}

function toChatMessages(input) {
  if (typeof input === 'string') {
    return [{ role: 'user', content: input }]
  }

  return input.flatMap(item => {
    if (item.type === 'message') {
      return [{ role: chatRole(item.role), content: textFromContent(item.content) }]
    }

    if (item.type === 'function_call_output') {
      return [{ role: 'tool', tool_call_id: item.call_id, content: item.output || '' }]
    }

    if (item.type === 'function_call') {
      return [{
        role: 'assistant',
        content: '',
        tool_calls: [{
          id: item.call_id,
          type: 'function',
          function: {
            name: item.name,
            arguments: item.arguments || '{}'
          }
        }]
      }]
    }

    if (typeof item.content === 'string') {
      return [{ role: chatRole(item.role), content: item.content }]
    }

    return []
  })
}

function chatRole(role) {
  return role === 'assistant' || role === 'system' || role === 'tool' ? role : 'user'
}

function textFromContent(content) {
  if (typeof content === 'string') {
    return content
  }

  if (!Array.isArray(content)) {
    return ''
  }

  return content.map(part => {
    if (typeof part === 'string') {
      return part
    }

    return part.text || part.input_text || part.output_text || ''
  }).filter(Boolean).join('\n')
}

function toChatTools(tools) {
  return tools.flatMap(tool => {
    if (tool.type === 'function') {
      return [{
        type: 'function',
        function: {
          name: tool.name,
          description: tool.description || '',
          parameters: tool.parameters || {}
        }
      }]
    }

    if (tool.name) {
      return [{
        type: 'function',
        function: {
          name: tool.name,
          description: tool.description || '',
          parameters: tool.parameters || {}
        }
      }]
    }

    return []
  })
}

function writeResponsesEventStream(res, chat) {
  const id = `resp_${randomUUID().replaceAll('-', '')}`
  const choice = chat.choices?.[0] || {}
  const message = choice.message || {}
  const output = toResponseOutput(message)
  const response = {
    id,
    object: 'response',
    created_at: Math.floor(Date.now() / 1000),
    status: 'completed',
    model: chat.model || 'deepseek-chat',
    output,
    usage: chat.usage || null
  }

  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    connection: 'keep-alive'
  })

  sendEvent(res, 'response.created', { type: 'response.created', response: { ...response, status: 'in_progress', output: [] } })
  output.forEach((item, index) => {
    sendEvent(res, 'response.output_item.added', { type: 'response.output_item.added', output_index: index, item: { ...item, status: 'in_progress' } })
    if (item.type === 'message') {
      const part = item.content[0]
      sendEvent(res, 'response.content_part.added', { type: 'response.content_part.added', item_id: item.id, output_index: index, content_index: 0, part })
      sendEvent(res, 'response.output_text.delta', { type: 'response.output_text.delta', item_id: item.id, output_index: index, content_index: 0, delta: part.text })
      sendEvent(res, 'response.output_text.done', { type: 'response.output_text.done', item_id: item.id, output_index: index, content_index: 0, text: part.text })
      sendEvent(res, 'response.content_part.done', { type: 'response.content_part.done', item_id: item.id, output_index: index, content_index: 0, part })
    }
    sendEvent(res, 'response.output_item.done', { type: 'response.output_item.done', output_index: index, item })
  })
  sendEvent(res, 'response.completed', { type: 'response.completed', response })
  res.end()
}

function toResponseOutput(message) {
  if (Array.isArray(message.tool_calls) && message.tool_calls.length > 0) {
    return message.tool_calls.map(call => ({
      id: `fc_${randomUUID().replaceAll('-', '')}`,
      type: 'function_call',
      status: 'completed',
      call_id: call.id,
      name: call.function?.name || call.name,
      arguments: call.function?.arguments || call.arguments || '{}'
    }))
  }

  return [{
    id: `msg_${randomUUID().replaceAll('-', '')}`,
    type: 'message',
    status: 'completed',
    role: 'assistant',
    content: [{
      type: 'output_text',
      text: message.content || '',
      annotations: []
    }]
  }]
}

function sendEvent(res, event, data) {
  res.write(`event: ${event}\n`)
  res.write(`data: ${JSON.stringify(data)}\n\n`)
}
