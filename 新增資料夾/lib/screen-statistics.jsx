// StatisticsScreen — filter / category chips / donut / category list

function DonutChart({ t, segments, size = 160 }) {
  const total = segments.reduce((s, x) => s + x.value, 0);
  let acc = 0;
  const r = size/2 - 12, cx = size/2, cy = size/2;
  const arcs = segments.map((s, i) => {
    const start = acc / total * Math.PI * 2 - Math.PI/2;
    acc += s.value;
    const end = acc / total * Math.PI * 2 - Math.PI/2;
    const large = end - start > Math.PI ? 1 : 0;
    const x1 = cx + Math.cos(start)*r, y1 = cy + Math.sin(start)*r;
    const x2 = cx + Math.cos(end)*r, y2 = cy + Math.sin(end)*r;
    const mx = cx + Math.cos((start+end)/2)*(r*0.7);
    const my = cy + Math.sin((start+end)/2)*(r*0.7);
    const pct = Math.round(s.value/total*100);
    return { d: `M ${cx} ${cy} L ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2} Z`, c: s.color, pct, mx, my };
  });
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {arcs.map((a,i) => (
        <g key={i}>
          <path d={a.d} fill={a.c} stroke={t.id==='retro'? t.border : '#fff'} strokeWidth={t.id==='retro'? 2 : 1.5}/>
          {a.pct >= 10 && (
            <text x={a.mx} y={a.my} fontFamily={t.fontBody} fontSize="11" fontWeight="700" fill="#fff" textAnchor="middle" dominantBaseline="central">{a.pct}%</text>
          )}
        </g>
      ))}
      <circle cx={cx} cy={cy} r={size*0.22} fill={t.surface} stroke={t.borderW? t.border : 'transparent'} strokeWidth={t.borderW || 0}/>
    </svg>
  );
}

function BarChart({ t, days = 7 }) {
  const vals = [3.2, 4.1, 2.5, 5.0, 4.3, 6.1, 3.8].slice(0, days);
  const max = Math.max(...vals);
  const labels = ['一','二','三','四','五','六','日'];
  return (
    <div style={{display:'flex', alignItems:'flex-end', gap:6, height:90, padding:'4px 0'}}>
      {vals.map((v,i) => (
        <div key={i} style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:4}}>
          <div style={{
            width:'100%', height:`${(v/max)*72}px`,
            background: t.id==='cartoon' ? t.accent : t.id==='retro' ? t.action : t.accent,
            border: t.borderW ? `${Math.min(2,t.borderW)}px solid ${t.border}` : 'none',
            borderRadius: t.id==='retro'? 0 : 4,
          }}/>
          <span style={{fontSize:9, color:t.mute, fontFamily:t.fontBody}}>{labels[i]}</span>
        </div>
      ))}
    </div>
  );
}

function StatisticsScreen({ t }) {
  const cats = SAMPLE_CATS.map(c => ({ ...c, value: c.mins }));
  const total = cats.reduce((s,c)=>s+c.mins, 0);
  return (
    <div style={{position:'relative', zIndex:1, padding:'4px 16px 24px'}}>
      <ThemedAppBar t={t} title="統計 📊"/>
      <div style={{padding:'4px 6px 0'}}>
        <FilterTabs t={t}
          options={[{value:'d', label:'日'},{value:'w', label:'週'},{value:'m', label:'月'},{value:'y', label:'年'}]}
          value="d" onChange={()=>{}}/>
      </div>

      {/* period nav */}
      <div style={{display:'flex', justifyContent:'center', alignItems:'center', gap:14, padding:'12px 0 6px',
        color: t.id==='cartoon'||t.id==='dark' ? '#fff' : t.ink, fontFamily:t.fontBody, fontSize:13, fontWeight:600}}>
        <span style={{opacity:0.6}}>‹</span>
        <span>2025 年 5 月 19 日</span>
        <span style={{opacity:0.3}}>›</span>
      </div>

      {/* Donut + legend */}
      <ThemedCard t={t} padding={16} style={{marginTop:8}}>
        <div style={{fontFamily:t.fontDisplay, fontSize:14, fontWeight:700, color:t.ink, marginBottom:8}}>時間分配</div>
        <div style={{display:'flex', alignItems:'center', gap:12}}>
          <DonutChart t={t} segments={cats} size={130}/>
          <div style={{flex:1, display:'flex', flexDirection:'column', gap:8}}>
            {cats.map(c => (
              <div key={c.name} style={{display:'flex', alignItems:'center', gap:8, fontFamily:t.fontBody, fontSize:12, color:t.ink, fontWeight:600}}>
                <div style={{width:10, height:10, borderRadius:'50%', background:c.color, border:t.id==='retro'?`1.5px solid ${t.border}`:'none'}}/>
                <span style={{flex:1}}>{c.name}</span>
                <span style={{fontFamily:t.fontTimer, fontSize:11, color:t.mute}}>{c.mins}m</span>
              </div>
            ))}
          </div>
        </div>
        <div style={{
          marginTop:12, padding:'6px 12px', textAlign:'center',
          background: t.surfaceAlt, borderRadius:t.chipRadius>50?999:10,
          border: t.borderW? `1.5px solid ${t.border}`: 'none',
          fontFamily:t.fontTimer, fontSize:14, fontWeight:700, color:t.accent,
        }}>合計 {fmtHMS(total*60)}</div>
      </ThemedCard>

      {/* Trend */}
      <div style={{fontFamily:t.fontDisplay, fontSize:13, fontWeight:700, color: t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.85)' : t.ink, padding:'18px 4px 8px', letterSpacing:0.5}}>近期趨勢</div>
      <ThemedCard t={t} padding={12}>
        <BarChart t={t} days={7}/>
      </ThemedCard>

      {/* Detail list */}
      <div style={{fontFamily:t.fontDisplay, fontSize:13, fontWeight:700, color: t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.85)' : t.ink, padding:'18px 4px 8px', letterSpacing:0.5}}>詳細項目</div>
      <div style={{display:'flex', flexDirection:'column', gap:8}}>
        {cats.map(c => (
          <ThemedCard key={c.name} t={t} padding={12}>
            <div style={{display:'flex', alignItems:'center', gap:10, fontFamily:t.fontBody}}>
              <div style={{width:10, height:10, borderRadius:'50%', background:c.color, border:t.id==='retro'?`1.5px solid ${t.border}`:'none'}}/>
              <span style={{flex:1, color:t.ink, fontWeight:700, fontSize:14}}>{c.name}</span>
              <span style={{fontFamily:t.fontTimer, color:t.accent, fontWeight:700, fontSize:14}}>{fmtHMS(c.mins*60)}</span>
              <span style={{color:t.mute, fontSize:14}}>›</span>
            </div>
          </ThemedCard>
        ))}
      </div>
    </div>
  );
}

window.StatisticsScreen = StatisticsScreen;
