export function createPlayer() {
  let state = 'stopped'
  let track = null
  let position = 0
  let bluetoothDevice = null

  return {
    load(file) {
      if (!file || !file.endsWith('.mp3')) throw new Error('Unsupported format')
      track = file
      position = 0
      state = 'playing'
    },
    pause() {
      if (state === 'playing') state = 'paused'
    },
    resume() {
      if (state === 'paused') state = 'playing'
    },
    stop() {
      state = 'stopped'
      position = 0
    },
    connectBluetooth(device) {
      bluetoothDevice = device
    },
    state() { return state },
    track() { return track },
    position() { return position },
    bluetoothDevice() { return bluetoothDevice },
  }
}
