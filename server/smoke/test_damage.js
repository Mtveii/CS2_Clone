const { WebSocket } = require('ws');
const PORT = process.env.GAME_SERVER_PORT || 7777;

function hello(name) {
  const n = Buffer.from(name);
  const b = Buffer.alloc(1 + 2 + 2 + 4 + 2 + n.length);
  let o = 0;
  b[o++] = 6; b[o++] = 1; b[o++] = 0; b[o++] = 1; b[o++] = 0;
  b.writeUInt32LE(0, o); o += 4;
  b.writeUInt16LE(n.length, o); o += 2;
  n.copy(b, o);
  return b;
}
function input(seq, buttons, mx, mz) {
  const b = Buffer.alloc(1 + 4 + 2 + 2 + 2 + 4 + 4 + 2);
  let o = 0;
  b[o++] = 1; b.writeUInt32LE(seq, o); o += 4;
  b.writeUInt16LE(buttons, o); o += 2;
  b.writeInt16LE(mx, o); o += 2; b.writeInt16LE(mz, o); o += 2;
  b.writeInt32LE(0, o); o += 4; b.writeInt32LE(0, o); o += 4;
  b.writeUInt16LE(16, o); o += 2;
  return b;
}

const attacker = new WebSocket('ws://127.0.0.1:' + PORT);
const target = new WebSocket('ws://127.0.0.1:' + PORT);
let damaged = false;
let tick = 0;

target.on('message', (d) => {
  const b = Buffer.from(d);
  if (b[0] === 9) {
    const hp = b.readUInt16LE(9);
    console.log('DAMAGE received, hp=', hp);
    damaged = hp < 100;
  }
});
attacker.on('message', () => {});
attacker.on('open', () => attacker.send(hello('attacker')));
target.on('open', () => target.send(hello('target')));

const iv = setInterval(() => {
  tick++;
  if (tick < 4) target.send(input(tick, 0, 0, 32767));
  if (tick === 6) attacker.send(input(tick, 4, 0, 0));
  if (tick > 12) {
    clearInterval(iv);
    console.log(damaged ? 'RESULT: PASS' : 'RESULT: FAIL');
    process.exit(damaged ? 0 : 1);
  }
}, 16);
