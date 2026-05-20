// 9 theme tokens for Me Time. Each theme exposes the same shape
// so HomeScreen can render against any of them.
//
// shape:
//   id, name, zh
//   bg            CSS background for the page area (gradient or color)
//   surface       card / chip surface color
//   surfaceAlt    nested surface (today total pill, etc)
//   ink           primary text color
//   mute          secondary text color
//   accent        timer big-number color (and "running" glow)
//   accentSoft    soft tint of accent for halos
//   action        play-button fill
//   actionInk     play-button glyph color
//   active        selected category chip color
//   border        border color on cards / chips
//   borderW       border width px
//   shadow        hard-shadow color
//   shadowOff     px offset for hard shadow ([x,y])
//   radius        card radius
//   chipRadius
//   bubbles       what to render on the bg ('cartoon'|'paper'|'pixel'|'glow'|'none'|'y2k'|'leaf'|'pastel')
//   fontDisplay
//   fontBody
//   fontTimer
//   navBg         bottom-nav fill
//   navInk        bottom-nav text color
//   navBorder     bottom-nav top border
//   appBarInk     app-bar / "Me Time" wordmark color
//   chipInk       chip text (unselected)
//   chipInkSel    chip text (selected)
//   chipBg        chip bg unselected
//   timerLabel    text above big number ("ME TIME ⏱")
//   running       text shown when timer is running ("GO GO GO!")
//   timerHaloOn   show neon glow ring behind timer when running
//   extras        per-theme bg decorations (string token only; rendered by Bubbles)

const THEMES = [
  // 1. Cartoon (original)
  {
    id: 'cartoon', name: 'Cartoon', zh: '卡通原版',
    bg: 'linear-gradient(135deg, #48CAE4 0%, #0077B6 100%)',
    surface: '#FFFDE7', surfaceAlt: 'rgba(26,26,46,0.06)',
    ink: '#1A1A2E', mute: 'rgba(255,255,255,0.7)',
    accent: '#FF8F00', accentSoft: 'rgba(255,179,0,0.5)',
    action: '#FFD60A', actionInk: '#1A1A2E',
    active: '#FFD60A',
    border: '#1A1A2E', borderW: 3.5, shadow: '#1A1A2E', shadowOff: [5,5],
    radius: 28, chipRadius: 14,
    bubbles: 'cartoon',
    fontDisplay: 'Fredoka', fontBody: 'Outfit', fontTimer: 'Fredoka',
    navBg: '#FFFDE7', navInk: '#1A1A2E', navBorder: '#1A1A2E',
    appBarInk: 'rgba(255,255,255,0.92)',
    chipInk: '#1A1A2E', chipInkSel: '#fff', chipBg: 'rgba(255,255,255,0.9)',
    timerLabel: 'ME TIME ⏱', running: 'GO GO GO! 🎯',
    timerHaloOn: false,
  },

  // 2. Dark cartoon
  {
    id: 'dark', name: 'Dark Cartoon', zh: '深色卡通',
    bg: 'linear-gradient(160deg, #0B1020 0%, #1A1A2E 60%, #06070D 100%)',
    surface: '#1E1F36', surfaceAlt: 'rgba(255,255,255,0.06)',
    ink: '#F4F2E7', mute: 'rgba(244,242,231,0.6)',
    accent: '#FFD166', accentSoft: 'rgba(255,209,102,0.45)',
    action: '#FFD166', actionInk: '#1A1A2E',
    active: '#FFD166',
    border: '#F4F2E7', borderW: 3, shadow: '#48CAE4', shadowOff: [5,5],
    radius: 28, chipRadius: 14,
    bubbles: 'cartoon-dark',
    fontDisplay: 'Fredoka', fontBody: 'Outfit', fontTimer: 'Fredoka',
    navBg: '#0B1020', navInk: '#F4F2E7', navBorder: '#48CAE4',
    appBarInk: '#F4F2E7',
    chipInk: '#F4F2E7', chipInkSel: '#1A1A2E', chipBg: 'rgba(255,255,255,0.08)',
    timerLabel: 'ME TIME ⏱', running: 'GO GO GO! 🌙',
    timerHaloOn: true,
  },

  // 3. Retro khaki — like an old terminal / vintage paper computer
  {
    id: 'retro', name: 'Retro', zh: '復古卡其',
    bg: '#D4C4A0',
    surface: '#EADFC4', surfaceAlt: '#C9B687',
    ink: '#3D2F1F', mute: '#7A6647',
    accent: '#8B4513', accentSoft: 'rgba(139,69,19,0.25)',
    action: '#A0522D', actionInk: '#F5EDD8',
    active: '#8B6F3A',
    border: '#3D2F1F', borderW: 3, shadow: '#3D2F1F', shadowOff: [4,4],
    radius: 4, chipRadius: 2,
    bubbles: 'pixel',
    fontDisplay: 'Press Start 2P', fontBody: 'VT323', fontTimer: 'Press Start 2P',
    navBg: '#8B6F3A', navInk: '#F5EDD8', navBorder: '#3D2F1F',
    appBarInk: '#3D2F1F',
    chipInk: '#3D2F1F', chipInkSel: '#F5EDD8', chipBg: '#EADFC4',
    timerLabel: 'ME TIME', running: 'GO! GO! GO!',
    timerHaloOn: false,
  },

  // 4. Pastel macaron
  {
    id: 'pastel', name: 'Pastel', zh: '馬卡龍',
    bg: 'linear-gradient(160deg, #FFE5EC 0%, #FFC9DE 35%, #C8B6FF 100%)',
    surface: '#FFFFFF', surfaceAlt: '#FFE5EC',
    ink: '#6B3F61', mute: 'rgba(107,63,97,0.55)',
    accent: '#FF8FA3', accentSoft: 'rgba(255,143,163,0.35)',
    action: '#FFB3C6', actionInk: '#6B3F61',
    active: '#C8B6FF',
    border: '#FFB3C6', borderW: 0, shadow: 'rgba(200,150,180,0.35)', shadowOff: [0,12],
    radius: 32, chipRadius: 22,
    bubbles: 'pastel',
    fontDisplay: 'Quicksand', fontBody: 'Quicksand', fontTimer: 'Quicksand',
    navBg: 'rgba(255,255,255,0.7)', navInk: '#6B3F61', navBorder: 'rgba(255,143,163,0.4)',
    appBarInk: '#6B3F61',
    chipInk: '#6B3F61', chipInkSel: '#fff', chipBg: '#FFFFFF',
    timerLabel: 'me time', running: 'focus mode',
    timerHaloOn: false,
  },

  // 5. Minimal
  {
    id: 'minimal', name: 'Minimal', zh: '極簡',
    bg: '#FAFAF7',
    surface: '#FFFFFF', surfaceAlt: '#F1F0EB',
    ink: '#111111', mute: '#9A9A95',
    accent: '#111111', accentSoft: 'rgba(0,0,0,0.08)',
    action: '#111111', actionInk: '#FFFFFF',
    active: '#111111',
    border: 'transparent', borderW: 0, shadow: 'transparent', shadowOff: [0,0],
    radius: 16, chipRadius: 10,
    bubbles: 'none',
    fontDisplay: 'Inter', fontBody: 'Inter', fontTimer: 'JetBrains Mono',
    navBg: '#FFFFFF', navInk: '#111111', navBorder: '#EEEEEA',
    appBarInk: '#111111',
    chipInk: '#666', chipInkSel: '#fff', chipBg: '#F1F0EB',
    timerLabel: 'me time', running: 'focus',
    timerHaloOn: false,
  },
];

window.THEMES = THEMES;
window.THEMES_BY_ID = Object.fromEntries(THEMES.map(t => [t.id, t]));
