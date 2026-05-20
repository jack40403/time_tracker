// GoalsScreen — list of goals with progress bars

const SAMPLE_GOALS = [
  { title:'閱讀', period:'每日', target: 60, actual: 47, color:'#FF8FA3', type:'time' },
  { title:'運動', period:'每週', target: 5, actual: 3, color:'#6B8E4E', type:'task', unit:'次' },
  { title:'學日文', period:'每日', target: 30, actual: 28, color:'#7BB3E0', type:'time' },
  { title:'寫程式', period:'每日', target: 90, actual: 33, color:'#C5B7FF', type:'time' },
];

function GoalCard({ t, g }) {
  const pct = Math.min(100, Math.round(g.actual / g.target * 100));
  const done = pct >= 100;
  const valueLabel = g.type==='time' ? `${g.actual}m / ${g.target}m` : `${g.actual}${g.unit} / ${g.target}${g.unit}`;
  return (
    <ThemedCard t={t} padding={14}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:10, fontFamily:t.fontBody}}>
        <div style={{width:24, height:24, borderRadius:t.id==='retro'?0:'50%', background:g.color, display:'grid', placeItems:'center',
          border: t.id==='retro'? `2px solid ${t.border}` : 'none'}}>
          <span style={{fontSize:11, fontWeight:800, color:'#fff'}}>{g.type==='time'?'⏱':g.type==='task'?'#':'✓'}</span>
        </div>
        <div style={{flex:1}}>
          <div style={{fontWeight:700, fontSize:14, color:t.ink}}>{g.title}</div>
          <div style={{fontSize:11, color:t.mute, marginTop:1}}>{g.period}</div>
        </div>
        <div style={{fontFamily:t.fontTimer, fontSize:12, fontWeight:700, color: done? t.accent : t.ink}}>{valueLabel}</div>
      </div>
      {/* progress bar */}
      <div style={{
        height: t.id==='retro'? 10 : 8, borderRadius: t.id==='retro'? 0 : 99,
        background: t.surfaceAlt,
        border: t.id==='retro' ? `2px solid ${t.border}` : 'none',
        overflow:'hidden', position:'relative',
      }}>
        <div style={{
          width:`${pct}%`, height:'100%',
          background: done ? '#4caf50' : g.color,
          borderRadius:'inherit',
          transition:'width .3s',
        }}/>
      </div>
      <div style={{display:'flex', justifyContent:'space-between', marginTop:6, fontFamily:t.fontBody, fontSize:10, color:t.mute}}>
        <span>{done ? '✅ 已達成' : `還差 ${g.target-g.actual}${g.type==='time'?'m':g.unit}`}</span>
        <span style={{fontFamily:t.fontTimer, fontWeight:700}}>{pct}%</span>
      </div>
    </ThemedCard>
  );
}

function GoalsScreen({ t }) {
  return (
    <div style={{position:'relative', zIndex:1, padding:'4px 16px 24px'}}>
      <ThemedAppBar t={t} title="專注目標 🎯"
        action={
          <div style={{
            width:28, height:28, display:'grid', placeItems:'center',
            background: t.action, color: t.actionInk,
            border: t.borderW ? `2px solid ${t.border}` : 'none',
            borderRadius: t.chipRadius>50? 999 : 8,
            boxShadow: t.shadow!=='transparent'? `2px 2px 0 ${t.shadow}` : 'none',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>
          </div>
        }/>

      <div style={{padding:'10px 4px', fontFamily:t.fontBody, fontSize:11, color: t.id==='cartoon'||t.id==='dark' ? 'rgba(255,255,255,0.6)' : t.mute, letterSpacing:0.8}}>
        本週進度 · 4 個目標 · 1 個已達成
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:10}}>
        {SAMPLE_GOALS.map((g,i)=> <GoalCard key={i} t={t} g={g}/>)}
      </div>
    </div>
  );
}

window.GoalsScreen = GoalsScreen;
