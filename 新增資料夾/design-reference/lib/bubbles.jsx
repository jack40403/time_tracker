// Bubbles / decoration layer per theme.
// Mounted absolutely inside the phone content area.

function ThemeBubbles({ t }) {
  const k = t.bubbles;
  const wrap = { position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden' };

  if (k === 'cartoon' || k === 'cartoon-dark') {
    const dark = k === 'cartoon-dark';
    const fill = dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.13)';
    const stroke = dark ? 'rgba(72,202,228,0.25)' : 'rgba(255,255,255,0.22)';
    const cfgs = [
      { s:80, t:40, l:-20 }, { s:50, t:130, r:10 }, { s:35, t:220, l:20 },
      { s:60, b:220, r:-15 }, { s:28, b:340, l:28 }, { s:45, b:120, l:60 },
    ];
    return <div style={wrap}>{cfgs.map((c,i)=>(
      <div key={i} style={{
        position:'absolute', width:c.s, height:c.s, borderRadius:'50%',
        background:fill, border:`2px solid ${stroke}`,
        top:c.t, bottom:c.b, left:c.l, right:c.r,
      }}/>
    ))}</div>;
  }

  if (k === 'pixel') {
    // chunky khaki pixel dots
    const cells = [];
    for (let i=0;i<40;i++){
      cells.push({ x: (i*73)%100, y: (i*131)%100, s: 6 + (i%2)*4 });
    }
    return <div style={wrap}>
      {cells.map((c,i)=>(
        <div key={i} style={{
          position:'absolute', width:c.s, height:c.s,
          left:`${c.x}%`, top:`${c.y}%`,
          background:'rgba(61,47,31,0.07)',
        }}/>
      ))}
      {/* faint horizontal scan lines like an old CRT */}
      <div style={{position:'absolute', inset:0,
        background:'repeating-linear-gradient(0deg, transparent 0 3px, rgba(61,47,31,0.04) 3px 4px)'}}/>
    </div>;
  }

  if (k === 'pastel') {
    return <div style={wrap}>
      <div style={{position:'absolute', top:-40, right:-40, width:180, height:180, borderRadius:'50%', background:'radial-gradient(circle, #FFB3C6 0%, transparent 70%)', opacity:0.6}}/>
      <div style={{position:'absolute', top:140, left:-50, width:160, height:160, borderRadius:'50%', background:'radial-gradient(circle, #C8B6FF 0%, transparent 70%)', opacity:0.5}}/>
      <div style={{position:'absolute', bottom:60, right:-30, width:140, height:140, borderRadius:'50%', background:'radial-gradient(circle, #FFE5EC 0%, transparent 70%)', opacity:0.7}}/>
    </div>;
  }

  if (k === 'y2k') {
    return <div style={wrap}>
      <div style={{position:'absolute', top:50, right:20, fontSize:24, color:'rgba(26,31,77,0.4)'}}>✦</div>
      <div style={{position:'absolute', top:200, left:30, fontSize:18, color:'rgba(26,31,77,0.3)'}}>★</div>
      <div style={{position:'absolute', bottom:200, right:40, fontSize:32, color:'rgba(255,79,163,0.5)'}}>✦</div>
      <div style={{position:'absolute', bottom:380, left:40, fontSize:14, color:'rgba(26,31,77,0.35)'}}>✧</div>
      {/* metallic streaks */}
      <div style={{position:'absolute', inset:0, background:'repeating-linear-gradient(135deg, transparent 0 40px, rgba(255,255,255,0.08) 40px 41px)'}}/>
    </div>;
  }

  if (k === 'paper') {
    return <div style={wrap}>
      {/* paper noise + faint lines */}
      <div style={{position:'absolute', inset:0,
        background:'repeating-linear-gradient(0deg, transparent 0 28px, rgba(58,46,31,0.05) 28px 29px)',
      }}/>
      <div style={{position:'absolute', top:60, right:30, width:24, height:24, border:'1.5px dashed rgba(58,46,31,0.3)', borderRadius:'50%'}}/>
      <div style={{position:'absolute', top:160, left:24, fontSize:22, color:'rgba(58,46,31,0.3)', fontFamily:'Caveat'}}>★</div>
      <div style={{position:'absolute', bottom:240, right:40, fontSize:18, color:'rgba(194,65,12,0.4)'}}>✧</div>
    </div>;
  }

  if (k === 'leaf') {
    return <div style={wrap}>
      {[{t:50,r:20,s:60,rot:30},{t:240,l:-20,s:80,rot:-40},{b:200,r:-10,s:50,rot:120},{b:360,l:30,s:40,rot:200}].map((l,i)=>(
        <svg key={i} width={l.s} height={l.s} viewBox="0 0 100 100" style={{
          position:'absolute', top:l.t, bottom:l.b, left:l.l, right:l.r,
          transform:`rotate(${l.rot}deg)`, opacity:0.2,
        }}>
          <path d="M50 5 Q 90 50, 50 95 Q 10 50, 50 5 Z" fill="#3A4A2E"/>
          <path d="M50 5 L 50 95" stroke="#3A4A2E" strokeWidth="1.5" fill="none"/>
        </svg>
      ))}
    </div>;
  }

  if (k === 'glow') {
    return <div style={wrap}>
      <div style={{position:'absolute', top:-80, left:-80, width:300, height:300, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(255,54,242,0.35) 0%, transparent 60%)'}}/>
      <div style={{position:'absolute', bottom:-60, right:-60, width:260, height:260, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(0,240,255,0.3) 0%, transparent 60%)'}}/>
      {/* grid */}
      <div style={{position:'absolute', inset:0,
        backgroundImage:`linear-gradient(rgba(0,240,255,0.07) 1px, transparent 1px), linear-gradient(90deg, rgba(0,240,255,0.07) 1px, transparent 1px)`,
        backgroundSize:'32px 32px',
        maskImage:'linear-gradient(180deg, transparent, black 30%, black 70%, transparent)',
        WebkitMaskImage:'linear-gradient(180deg, transparent, black 30%, black 70%, transparent)',
      }}/>
    </div>;
  }

  return null;
}

window.ThemeBubbles = ThemeBubbles;
