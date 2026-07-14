import http from 'node:http'
import { randomUUID } from 'node:crypto'

const port = Number(process.env.CLAUDE_OPENAI_PROXY_PORT || '8783')
const apiKey = process.env.OPENAI_API_KEY

if (!apiKey) {
  console.error('Claude OpenAI proxy requires OPENAI_API_KEY')
  process.exit(1)
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') {
      writeJson(res, 200, { ok: true })
      return
    }

    if (req.method !== 'POST' || !req.url?.startsWith('/v1/messages')) {
      writeJson(res, 404, { type: 'error', error: { type: 'not_found_error', message: 'not found' } })
      return
    }

    const body = await readJson(req)
    const openaiResponse = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify(toResponsesRequest(body))
    })

    if (!openaiResponse.ok) {
      const message = await openaiResponse.text()
      writeJson(res, openaiResponse.status, { type: 'error', error: { type: 'api_error', message } })
      return
    }

    const response = toAnthropicMessage(await openaiResponse.json())
    if (body.stream) {
      writeAnthropicEventStream(res, response)
      return
    }

    writeJson(res, 200, response)
  } catch (error) {
    writeJson(res, 500, {
      type: 'error',
      error: { type: 'api_error', message: error instanceof Error ? error.message : String(error) }
    })
  }
})

server.listen(port, '127.0.0.1', () => {
  console.error(`claude-openai-responses-proxy listening on ${port}`)
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

function toResponsesRequest(request) {
  const tools = (request.tools || []).map(tool => ({
    type: 'function',
    name: tool.name,
    description: tool.description || '',
    parameters: tool.input_schema || { type: 'object', properties: {} },
    strict: false
  }))
  const responsesRequest = {
    model: 'gpt-5.6-luna',
    input: toResponsesInput(request.messages || []),
    max_output_tokens: request.max_tokens,
    stream: false
  }
  const instructions = textContent(request.system)
  if (instructions) {
    responsesRequest.instructions = instructions
  }
  if (tools.length > 0) {
    responsesRequest.tools = tools
    responsesRequest.tool_choice = toResponsesToolChoice(request.tool_choice)
  }
  return responsesRequest
}

function toResponsesInput(messages) {
  const input = []
  for (const message of messages) {
    const blocks = Array.isArray(message.content) ? message.content : [{ type: 'text', text: message.content }]
    let text = []
    const flushText = () => {
      if (text.length === 0) {
        return
      }
      input.push({ role: message.role, content: text.join('\n') })
      text = []
    }

    for (const block of blocks) {
      if (block.type === 'text') {
        text.push(block.text || '')
        continue
      }
      if (block.type === 'tool_use') {
        flushText()
        input.push({
          type: 'function_call',
          call_id: block.id,
          name: block.name,
          arguments: JSON.stringify(block.input || {})
        })
        continue
      }
      if (block.type === 'tool_result') {
        flushText()
        input.push({
          type: 'function_call_output',
          call_id: block.tool_use_id,
          output: textContent(block.content)
        })
      }
    }
    flushText()
  }
  return input
}

function toResponsesToolChoice(toolChoice) {
  if (!toolChoice || toolChoice.type === 'auto') {
    return 'auto'
  }
  if (toolChoice.type === 'any') {
    return 'required'
  }
  if (toolChoice.type === 'none') {
    return 'none'
  }
  if (toolChoice.type === 'tool') {
    return { type: 'function', name: toolChoice.name }
  }
  throw new Error(`Unsupported tool choice: ${toolChoice.type}`)
}

function textContent(content) {
  if (typeof content === 'string') {
    return content
  }
  if (!Array.isArray(content)) {
    return ''
  }
  return content.map(block => {
    if (typeof block === 'string') {
      return block
    }
    return block.text || ''
  }).filter(Boolean).join('\n')
}

function toAnthropicMessage(response) {
  const content = []
  for (const item of response.output || []) {
    if (item.type === 'message') {
      const text = (item.content || []).map(part => part.text || part.refusal || '').filter(Boolean).join('\n')
      if (text) {
        content.push({ type: 'text', text })
      }
      continue
    }
    if (item.type === 'function_call') {
      content.push({
        type: 'tool_use',
        id: item.call_id,
        name: item.name,
        input: JSON.parse(item.arguments || '{}')
      })
    }
  }
  if (content.length === 0) {
    throw new Error('OpenAI response contains no message or function call')
  }
  return {
    id: `msg_${randomUUID().replaceAll('-', '')}`,
    type: 'message',
    role: 'assistant',
    model: response.model || 'gpt-5.6-luna',
    content,
    stop_reason: content.some(block => block.type === 'tool_use') ? 'tool_use' : 'end_turn',
    stop_sequence: null,
    usage: {
      input_tokens: response.usage?.input_tokens || 0,
      output_tokens: response.usage?.output_tokens || 0
    }
  }
}

function writeAnthropicEventStream(res, message) {
  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    connection: 'keep-alive'
  })
  sendEvent(res, 'message_start', {
    type: 'message_start',
    message: { ...message, content: [], stop_reason: null, usage: { ...message.usage, output_tokens: 0 } }
  })
  message.content.forEach((block, index) => {
    if (block.type === 'text') {
      sendEvent(res, 'content_block_start', { type: 'content_block_start', index, content_block: { type: 'text', text: '' } })
      sendEvent(res, 'content_block_delta', { type: 'content_block_delta', index, delta: { type: 'text_delta', text: block.text } })
    } else {
      sendEvent(res, 'content_block_start', {
        type: 'content_block_start',
        index,
        content_block: { type: 'tool_use', id: block.id, name: block.name, input: {} }
      })
      sendEvent(res, 'content_block_delta', {
        type: 'content_block_delta',
        index,
        delta: { type: 'input_json_delta', partial_json: JSON.stringify(block.input) }
      })
    }
    sendEvent(res, 'content_block_stop', { type: 'content_block_stop', index })
  })
  sendEvent(res, 'message_delta', {
    type: 'message_delta',
    delta: { stop_reason: message.stop_reason, stop_sequence: null },
    usage: { output_tokens: message.usage.output_tokens }
  })
  sendEvent(res, 'message_stop', { type: 'message_stop' })
  res.end()
}

function sendEvent(res, event, data) {
  res.write(`event: ${event}\n`)
  res.write(`data: ${JSON.stringify(data)}\n\n`)
}

function writeJson(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' })
  res.end(JSON.stringify(body))
}
