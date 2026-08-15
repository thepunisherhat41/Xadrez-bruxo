import {
  Animation,
  ArcRotateCamera,
  Color3,
  Color4,
  Engine,
  GlowLayer,
  HemisphericLight,
  MeshBuilder,
  ParticleSystem,
  PointLight,
  Scene,
  StandardMaterial,
  Texture,
  Vector3,
} from '@babylonjs/core';
import '@babylonjs/core/Animations/animatable.js';

const FILES = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const PIECE_NAMES = { p: 'Peão', r: 'Torre', n: 'Cavalo', b: 'Bispo', q: 'Rainha', k: 'Rei' };

function squarePosition(square) {
  const file = FILES.indexOf(square[0]);
  const rank = Number(square[1]) - 1;
  return new Vector3(file - 3.5, 0.35, rank - 3.5);
}

function makeMaterial(scene, name, color, emissive = null) {
  const material = new StandardMaterial(name, scene);
  material.diffuseColor = color;
  material.specularColor = new Color3(0.9, 0.9, 1);
  material.specularPower = 96;
  if (emissive) material.emissiveColor = emissive;
  return material;
}

function attachMetadata(mesh, square, piece) {
  mesh.metadata = { square, piece };
  mesh.getChildMeshes().forEach((child) => {
    child.metadata = { square, piece };
  });
}

function buildPiece(scene, piece, square, materials) {
  const root = MeshBuilder.CreateCylinder(`piece-${square}`, { height: 0.16, diameterTop: 0.82, diameterBottom: 0.94, tessellation: 24 }, scene);
  root.material = piece.color === 'w' ? materials.whitePiece : materials.blackPiece;
  root.position = squarePosition(square);
  root.position.y = 0.5;

  const base2 = MeshBuilder.CreateCylinder(`base-${square}`, { height: 0.12, diameterTop: 0.68, diameterBottom: 0.82, tessellation: 24 }, scene);
  base2.parent = root;
  base2.position.y = 0.12;
  base2.material = root.material;

  const body = MeshBuilder.CreateCylinder(`body-${square}`, { height: piece.type === 'p' ? 0.55 : 0.72, diameterTop: 0.28, diameterBottom: 0.48, tessellation: 20 }, scene);
  body.parent = root;
  body.position.y = piece.type === 'p' ? 0.46 : 0.55;
  body.material = root.material;

  if (piece.type === 'p') {
    const head = MeshBuilder.CreateSphere(`head-${square}`, { diameter: 0.38, segments: 18 }, scene);
    head.parent = root;
    head.position.y = 0.83;
    head.material = root.material;
  }

  if (piece.type === 'r') {
    const crown = MeshBuilder.CreateBox(`crown-${square}`, { width: 0.54, depth: 0.54, height: 0.3 }, scene);
    crown.parent = root;
    crown.position.y = 1.02;
    crown.material = root.material;
  }

  if (piece.type === 'n') {
    const neck = MeshBuilder.CreateCylinder(`neck-${square}`, { height: 0.58, diameterTop: 0.3, diameterBottom: 0.42, tessellation: 16 }, scene);
    neck.parent = root;
    neck.position = new Vector3(0, 0.93, 0.08);
    neck.rotation.x = -0.35;
    neck.material = root.material;
    const head = MeshBuilder.CreateSphere(`horse-${square}`, { diameter: 0.42, segments: 16 }, scene);
    head.parent = root;
    head.position = new Vector3(0, 1.23, -0.1);
    head.scaling.z = 1.35;
    head.material = root.material;
  }

  if (piece.type === 'b') {
    const mitre = MeshBuilder.CreateSphere(`mitre-${square}`, { diameter: 0.46, segments: 18 }, scene);
    mitre.parent = root;
    mitre.position.y = 1.05;
    mitre.scaling.y = 1.4;
    mitre.material = root.material;
  }

  if (piece.type === 'q' || piece.type === 'k') {
    const crown = MeshBuilder.CreateSphere(`royal-${square}`, { diameter: piece.type === 'q' ? 0.5 : 0.46, segments: 20 }, scene);
    crown.parent = root;
    crown.position.y = 1.12;
    crown.scaling.y = 1.25;
    crown.material = root.material;
    const aura = MeshBuilder.CreateTorus(`aura-${square}`, { diameter: 0.55, thickness: 0.055, tessellation: 24 }, scene);
    aura.parent = root;
    aura.position.y = 1.35;
    aura.rotation.x = Math.PI / 2;
    aura.material = piece.color === 'w' ? materials.whiteGlow : materials.blackGlow;
  }

  root.scaling = new Vector3(0.72, 0.72, 0.72);
  attachMetadata(root, square, piece);
  return root;
}

function parseFen(fen) {
  const board = [];
  const rows = fen.split(' ')[0].split('/');
  rows.forEach((row, rowIndex) => {
    let file = 0;
    for (const token of row) {
      if (/\d/.test(token)) {
        file += Number(token);
      } else {
        const color = token === token.toUpperCase() ? 'w' : 'b';
        const type = token.toLowerCase();
        const square = `${FILES[file]}${8 - rowIndex}`;
        board.push({ square, type, color });
        file += 1;
      }
    }
  });
  return board;
}

export function createBattleScene(canvas, onSquareClick) {
  const engine = new Engine(canvas, true, { preserveDrawingBuffer: true, stencil: true, antialias: true });
  const scene = new Scene(engine);
  scene.clearColor = new Color4(0.018, 0.025, 0.07, 1);
  scene.fogMode = Scene.FOGMODE_EXP2;
  scene.fogDensity = 0.018;
  scene.fogColor = new Color3(0.025, 0.035, 0.09);

  const camera = new ArcRotateCamera('camera', -Math.PI / 2, 1.05, 12.6, new Vector3(0, 0.25, 0), scene);
  camera.lowerRadiusLimit = 8.5;
  camera.upperRadiusLimit = 17;
  camera.lowerBetaLimit = 0.62;
  camera.upperBetaLimit = 1.35;
  camera.wheelPrecision = 40;
  camera.attachControl(canvas, true);

  const hemi = new HemisphericLight('hemi', new Vector3(0, 1, 0), scene);
  hemi.intensity = 0.7;
  hemi.diffuse = new Color3(0.34, 0.44, 0.8);

  const warm = new PointLight('warm', new Vector3(-5, 6, -5), scene);
  warm.diffuse = new Color3(1, 0.34, 0.08);
  warm.intensity = 10;
  const cool = new PointLight('cool', new Vector3(5, 5, 5), scene);
  cool.diffuse = new Color3(0.1, 0.42, 1);
  cool.intensity = 12;

  const glow = new GlowLayer('glow', scene, { blurKernelSize: 32 });
  glow.intensity = 0.65;

  const materials = {
    light: makeMaterial(scene, 'light-square', new Color3(0.34, 0.3, 0.42)),
    dark: makeMaterial(scene, 'dark-square', new Color3(0.055, 0.065, 0.12)),
    frame: makeMaterial(scene, 'frame', new Color3(0.07, 0.055, 0.045)),
    whitePiece: makeMaterial(scene, 'ivory', new Color3(0.82, 0.84, 0.92), new Color3(0.035, 0.07, 0.14)),
    blackPiece: makeMaterial(scene, 'obsidian', new Color3(0.075, 0.08, 0.12), new Color3(0.12, 0.02, 0.015)),
    whiteGlow: makeMaterial(scene, 'white-glow', new Color3(0.12, 0.5, 1), new Color3(0.1, 0.55, 1)),
    blackGlow: makeMaterial(scene, 'black-glow', new Color3(1, 0.16, 0.04), new Color3(1, 0.08, 0.02)),
    selected: makeMaterial(scene, 'selected', new Color3(0.18, 0.55, 1), new Color3(0.08, 0.38, 1)),
    legal: makeMaterial(scene, 'legal', new Color3(0.1, 0.46, 0.3), new Color3(0.02, 0.2, 0.1)),
  };

  const boardBase = MeshBuilder.CreateBox('board-base', { width: 9.4, depth: 9.4, height: 0.38 }, scene);
  boardBase.position.y = -0.22;
  boardBase.material = materials.frame;

  const squareMeshes = new Map();
  for (let rank = 0; rank < 8; rank += 1) {
    for (let file = 0; file < 8; file += 1) {
      const square = `${FILES[file]}${rank + 1}`;
      const mesh = MeshBuilder.CreateBox(`square-${square}`, { width: 0.98, depth: 0.98, height: 0.12 }, scene);
      mesh.position = new Vector3(file - 3.5, 0.02, rank - 3.5);
      mesh.material = (file + rank) % 2 === 0 ? materials.light : materials.dark;
      mesh.metadata = { square, baseMaterial: mesh.material };
      squareMeshes.set(square, mesh);
    }
  }

  for (let i = 0; i < 4; i += 1) {
    const ring = MeshBuilder.CreateTorus(`ring-${i}`, { diameter: 10.4 + i * 0.55, thickness: 0.025, tessellation: 96 }, scene);
    ring.rotation.x = Math.PI / 2;
    ring.position.y = -0.38 - i * 0.03;
    ring.material = i % 2 ? materials.whiteGlow : materials.blackGlow;
  }

  let pieceMeshes = new Map();

  function renderFen(fen) {
    pieceMeshes.forEach((mesh) => mesh.dispose());
    pieceMeshes = new Map();
    parseFen(fen).forEach((piece) => {
      const mesh = buildPiece(scene, piece, piece.square, materials);
      pieceMeshes.set(piece.square, mesh);
    });
  }

  function highlightSquares(selected, legal = []) {
    squareMeshes.forEach((mesh) => {
      mesh.material = mesh.metadata.baseMaterial;
    });
    if (selected && squareMeshes.has(selected)) squareMeshes.get(selected).material = materials.selected;
    legal.forEach((sq) => {
      if (squareMeshes.has(sq)) squareMeshes.get(sq).material = materials.legal;
    });
  }

  function burstAt(square, color = new Color3(0.25, 0.5, 1)) {
    const particles = new ParticleSystem(`burst-${Date.now()}`, 160, scene);
    particles.particleTexture = new Texture('https://assets.babylonjs.com/textures/flare.png', scene);
    particles.emitter = squarePosition(square).add(new Vector3(0, 0.85, 0));
    particles.minEmitBox = new Vector3(-0.08, -0.08, -0.08);
    particles.maxEmitBox = new Vector3(0.08, 0.08, 0.08);
    particles.color1 = new Color4(color.r, color.g, color.b, 1);
    particles.color2 = new Color4(1, 0.35, 0.08, 1);
    particles.colorDead = new Color4(0, 0, 0, 0);
    particles.minSize = 0.05;
    particles.maxSize = 0.2;
    particles.minLifeTime = 0.18;
    particles.maxLifeTime = 0.55;
    particles.emitRate = 900;
    particles.blendMode = ParticleSystem.BLENDMODE_ADD;
    particles.gravity = new Vector3(0, -5, 0);
    particles.direction1 = new Vector3(-3, 1, -3);
    particles.direction2 = new Vector3(3, 5, 3);
    particles.minAngularSpeed = 0;
    particles.maxAngularSpeed = Math.PI;
    particles.minEmitPower = 0.7;
    particles.maxEmitPower = 2.4;
    particles.updateSpeed = 0.012;
    particles.start();
    setTimeout(() => {
      particles.stop();
      setTimeout(() => particles.dispose(), 700);
    }, 90);
  }

  function animateMove(from, to, captured, callback) {
    const mesh = pieceMeshes.get(from);
    if (!mesh) {
      callback?.();
      return;
    }
    const start = mesh.position.clone();
    const end = squarePosition(to);
    end.y = start.y;
    const lift = start.add(end).scale(0.5);
    lift.y += captured ? 1.65 : 0.72;

    const animation = new Animation('move', 'position', 60, Animation.ANIMATIONTYPE_VECTOR3, Animation.ANIMATIONLOOPMODE_CONSTANT);
    animation.setKeys([
      { frame: 0, value: start },
      { frame: 18, value: lift },
      { frame: 36, value: end },
    ]);
    mesh.animations = [animation];
    scene.beginAnimation(mesh, 0, 36, false, 1, () => {
      if (captured) burstAt(to, mesh.metadata.piece.color === 'w' ? new Color3(0.2, 0.6, 1) : new Color3(1, 0.12, 0.02));
      callback?.();
    });
  }

  scene.onPointerDown = (_, pick) => {
    if (!pick.hit || !pick.pickedMesh) return;
    let target = pick.pickedMesh;
    while (target && !target.metadata?.square && target.parent) target = target.parent;
    const square = target?.metadata?.square;
    if (square) onSquareClick?.(square);
  };

  engine.runRenderLoop(() => {
    const t = performance.now() * 0.00012;
    warm.position.x = Math.sin(t) * 6;
    warm.position.z = Math.cos(t) * 6;
    cool.position.x = Math.cos(t * 0.8) * 6;
    cool.position.z = Math.sin(t * 0.8) * 6;
    scene.render();
  });

  const resize = () => engine.resize();
  window.addEventListener('resize', resize);

  return {
    renderFen,
    highlightSquares,
    animateMove,
    pieceLabel(square) {
      const piece = pieceMeshes.get(square)?.metadata?.piece;
      return piece ? PIECE_NAMES[piece.type] : null;
    },
    dispose() {
      window.removeEventListener('resize', resize);
      scene.dispose();
      engine.dispose();
    },
  };
}
