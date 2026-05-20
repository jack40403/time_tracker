// Splash — uses actual app_icon.png. Single combined keyframe loops gracefully:
// 0-25% pop in, then idle (icon visible) for the rest of the cycle.
// NOTE: @keyframes are defined globally in the root HTML <head> to avoid
// animation pending-state bugs in iframe/browser environments.

function SplashStage({ size = 260, loopMs = 4500, replayKey = 0 }) {
  const iconSize = size * 0.62;

  return (
    <div key={replayKey} style={{
      width: size, height: size, position:'relative',
      display:'grid', placeItems:'center',
    }}>

      {/* expanding ring (loops) */}
      <div style={{
        position:'absolute', width: iconSize*1.1, height: iconSize*1.1,
        borderRadius:'50%', border:'3px solid rgba(255,214,10,0.7)',
        animation:`splash-ring-loop ${loopMs}ms cubic-bezier(.2,.7,.3,1) 0.35s infinite`,
        pointerEvents:'none',
      }}/>
      <div style={{
        position:'absolute', width: iconSize*1.1, height: iconSize*1.1,
        borderRadius:'50%', border:'3px solid rgba(255,255,255,0.55)',
        animation:`splash-ring-loop ${loopMs}ms cubic-bezier(.2,.7,.3,1) 0.65s infinite`,
        pointerEvents:'none',
      }}/>

      {/* app icon: single keyframe with pop-then-rest. Image stays visible all cycle. */}
      <div style={{
        position:'relative', width: iconSize, height: iconSize,
        animation:`splash-pop-loop ${loopMs}ms cubic-bezier(.34,1.56,.64,1) infinite`,
        filter:'drop-shadow(0 12px 22px rgba(0,0,0,0.25))',
      }}>
        <img src="assets/app_icon.png" alt="Me Time" style={{
          display:'block', width:'100%', height:'100%', borderRadius: iconSize*0.18,
        }}/>
      </div>

      {/* sparkles above (loops) */}
      {[{x:'50%', d:0.85, s:1, c:'#FFD60A'}, {x:'34%', d:1.0, s:0.7, c:'#fff'}, {x:'66%', d:1.05, s:0.7, c:'#fff'}].map((p,i)=>(
        <div key={i} style={{
          position:'absolute', top:`${size*0.10}px`, left:p.x,
          animation:`splash-spark-loop ${loopMs}ms ease-out ${p.d}s infinite`,
        }}>
          <svg width={36*p.s} height={20*p.s} viewBox="0 0 36 20">
            <g stroke={p.c} strokeWidth="2.5" strokeLinecap="round" fill="none">
              <path d="M18 16 L18 4"/>
              <path d="M8 12 L4 6"/>
              <path d="M28 12 L32 6"/>
            </g>
          </svg>
        </div>
      ))}

      {/* bubbles flying outward (loops) */}
      {[
        { x:'18%', y:'30%', ex:-26, ey:-44, s:14, d:0.95 },
        { x:'82%', y:'28%', ex:38,  ey:-30, s:10, d:1.05 },
        { x:'88%', y:'68%', ex:46,  ey:34,  s:18, d:1.15 },
        { x:'12%', y:'76%', ex:-40, ey:32,  s:12, d:1.0  },
        { x:'50%', y:'90%', ex:0,   ey:42,  s:16, d:1.25 },
        { x:'24%', y:'52%', ex:-46, ey:0,   s:8,  d:1.1  },
        { x:'76%', y:'52%', ex:46,  ey:0,   s:8,  d:1.2  },
      ].map((b, i) => (
        <div key={i} style={{
          position:'absolute', left:b.x, top:b.y,
          width:b.s, height:b.s, borderRadius:'50%',
          background:'rgba(255,255,255,0.88)',
          border:'2px solid rgba(255,255,255,0.65)',
          boxShadow:'inset -2px -2px 0 rgba(255,255,255,0.6), 0 0 0 1px rgba(0,0,0,0.04)',
          '--bubble-end': `translate(${b.ex}px, ${b.ey}px)`,
          animation:`splash-bubble-loop ${loopMs}ms cubic-bezier(.34,1.2,.64,1) ${b.d}s infinite`,
        }}/>
      ))}
    </div>
  );
}

// Full-bleed splash inside a phone frame
function SplashPhone({ theme = window.THEMES_BY_ID.cartoon, replayKey = 0, label }) {
  return (
    <PhoneFrame t={theme} navActive={-1} label={label}>
      <div style={{
        position:'absolute', inset:0, display:'grid', placeItems:'center',
      }}>
        <SplashStage size={260} replayKey={replayKey}/>
      </div>
    </PhoneFrame>
  );
}

window.SplashStage = SplashStage;
window.SplashPhone = SplashPhone;
