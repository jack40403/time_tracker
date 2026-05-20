// PhoneFrame — Android-style bezel filled with themed background + content
// Single source of truth for size so design_canvas can lay out cards.

const PHONE_W = 360;
const PHONE_H = 740;

function PhoneFrame({ t, children, navActive=0, label }) {
  return (
    <div style={{
      width: PHONE_W, height: PHONE_H,
      borderRadius: 36, overflow:'hidden', position:'relative',
      background: '#0a0a0a',
      padding: 8, boxSizing:'border-box',
      boxShadow: '0 30px 60px rgba(0,0,0,0.18), 0 1px 2px rgba(0,0,0,0.2), inset 0 0 0 2px rgba(255,255,255,0.04)',
    }}>
      <div style={{
        width:'100%', height:'100%', borderRadius: 28, overflow:'hidden', position:'relative',
        background: t.bg,
        display:'flex', flexDirection:'column',
      }}>
        {/* themed bubble layer */}
        <ThemeBubbles t={t}/>

        {/* status bar */}
        <div style={{position:'relative', zIndex:2}}>
          <StatusBar t={t}/>
        </div>

        {/* notch */}
        <div style={{
          position:'absolute', left:'50%', top:8, transform:'translateX(-50%)',
          width:18, height:18, borderRadius:'50%', background:'#0a0a0a', zIndex:3,
        }}/>

        {/* content area */}
        <div style={{flex:1, position:'relative', zIndex:1, overflow:'hidden'}}>
          {children}
        </div>

        {/* bottom nav */}
        <div style={{position:'relative', zIndex:2}}>
          <BottomNav t={t} active={navActive}/>
        </div>

        {/* gesture pill */}
        <div style={{position:'absolute', bottom:6, left:'50%', transform:'translateX(-50%)',
          width:90, height:3, borderRadius:99,
          background: t.id==='neon' || t.id==='dark' ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.55)',
          zIndex:5,
        }}/>
      </div>
      {label && (
        <div style={{
          position:'absolute', bottom:-30, left:0, right:0, textAlign:'center',
          fontFamily:'Outfit, system-ui', fontSize:13, fontWeight:600, color:'#222', letterSpacing:0.5,
        }}>{label}</div>
      )}
    </div>
  );
}

window.PhoneFrame = PhoneFrame;
window.PHONE_W = PHONE_W;
window.PHONE_H = PHONE_H;
