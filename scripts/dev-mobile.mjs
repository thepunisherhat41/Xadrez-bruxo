import os from 'node:os';
import { spawn } from 'node:child_process';

function isPrivateIPv4(address) {
  if (!address || address.includes(':')) return false;
  if (address.startsWith('10.')) return true;
  if (address.startsWith('192.168.')) return true;
  const parts = address.split('.').map(Number);
  return parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31;
}

function detectLanIp() {
  const candidates = [];
  for (const entries of Object.values(os.networkInterfaces())) {
    for (const entry of entries || []) {
      if (entry.family === 'IPv4' && !entry.internal) candidates.push(entry.address);
    }
  }

  return candidates.find(isPrivateIPv4) || candidates[0] || '127.0.0.1';
}

const lanIp = process.env.MOBILE_HOST || detectLanIp();
const protocol = 'http';
const wsProtocol = 'ws';

console.log('\n🧙 Xadrez Bruxo — modo mobile local');
console.log(`📱 Abra no celular: ${protocol}://${lanIp}:5173`);
console.log(`🎮 Multiplayer: ${wsProtocol}://${lanIp}:2567`);
console.log('📡 O PC e o celular precisam estar na mesma rede Wi‑Fi.');
console.log('🛡️ Se o navegador não abrir, libere as portas 5173 e 2567 no firewall local.\n');

const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const child = spawn(npmCommand, ['run', 'dev'], {
  stdio: 'inherit',
  env: {
    ...process.env,
    VITE_WS_URL: `${wsProtocol}://${lanIp}:2567`,
  },
});

child.on('exit', (code) => process.exit(code ?? 0));
