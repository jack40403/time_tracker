// Main app: vertical 2-section layout.
//   ① splash card
//   ② interactive phone (tap nav, change theme in Settings)

const { useState } = React;

function ReplayButton({ onReplay }) {
  return (
    <button onClick={onReplay} style={{
      position:'absolute', top:8, right:8,
      display:'flex', alignItems:'center', gap:6,
      padding:'8px 14px',
      background:'#1A1A2E', color:'#fff',
      border:'none', borderRadius:99,
      fontFamily:'Outfit, system-ui', fontSize:12, fontWeight:600,
      cursor:'pointer', boxShadow:'0 6px 16px rgba(0,0,0,0.2)',
      zIndex:10,
    }}>
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 12a9 9 0 109-9 9.7 9.7 0 00-6.6 2.6L3 8"/><path d="M3 3v5h5"/>
      </svg>
      重播
    </button>
  );
}

function Card({ caption, children, hint }) {
  return (
    <div style={{
      display:'flex', flexDirection:'column', alignItems:'center', gap:14,
      scrollSnapAlign:'start', flex:'0 0 auto',
    }}>
      <div style={{position:'relative'}}>{children}</div>
      <div style={{
        fontFamily:'Outfit, system-ui', fontSize:13, fontWeight:600, color:'#222',
        letterSpacing:0.3, textAlign:'center',
      }}>{caption}</div>
      {hint && <div style={{
        fontFamily:'Outfit, system-ui', fontSize:11, color:'#888',
        textAlign:'center', maxWidth:360, lineHeight:1.5,
      }}>{hint}</div>}
    </div>
  );
}

function SplashCard() {
  const [k, setK] = useState(0);
  const t = window.THEMES_BY_ID.cartoon;
  return (
    <Card caption="開機畫面 · 原版">
      <ReplayButton onReplay={() => setK(x=>x+1)}/>
      <SplashPhone theme={t} replayKey={k}/>
    </Card>
  );
}

function Section({ title, subtitle, children, layout='center' }) {
  return (
    <section style={{padding:'40px 56px 16px'}}>
      <div style={{maxWidth:1200, margin:'0 auto 24px'}}>
        <div style={{
          fontFamily:'Fraunces, serif', fontSize:32, fontWeight:700, color:'#1d1d1f',
          letterSpacing:-0.5,
        }}>{title}</div>
        {subtitle && (
          <div style={{fontFamily:'Outfit', fontSize:15, color:'rgba(0,0,0,0.55)', marginTop:6}}>
            {subtitle}
          </div>
        )}
      </div>
      <div style={{
        display:'flex', gap:48, justifyContent: layout==='center'?'center':'flex-start',
        padding:'30px 56px', margin:'0 -56px',
        overflowX: 'auto', overflowY:'visible',
      }}>
        {children}
      </div>
    </section>
  );
}

function App() {
  return (
    <div style={{minHeight:'100vh', background:'#EAE6DC', paddingBottom:80}}>
      <header style={{padding:'56px 56px 16px', maxWidth:1200, margin:'0 auto'}}>
        <div style={{
          fontFamily:'Fraunces, serif', fontSize:46, fontWeight:700, color:'#1d1d1f',
          letterSpacing:-1, lineHeight:1.1,
        }}>Me Time<span style={{color:'#FF8F00'}}>·</span>開機動畫與主題探索</div>
        <div style={{
          fontFamily:'Outfit', fontSize:16, color:'rgba(0,0,0,0.6)', marginTop:10, maxWidth:760, lineHeight:1.5,
        }}>
          開機動畫使用實際 App Icon ·
          下方是<b>可互動</b>原型手機:點底部 nav 切換五個頁面,進入「設定」頁可以挑主題,
          整個 App 會即時換上你選的風格。
        </div>
      </header>

      <Section title="① 開機動畫" subtitle="自動循環播放 · 點右上「重播」可重看一次">
        <SplashCard/>
      </Section>

      <Section title="② 互動原型 (5 個頁面 · 5 種主題)"
        subtitle='底部 nav 可切換頁面 · 設定頁可切換主題 · 預設「Cartoon 原版」'>
        <Card
          caption="點底部導覽切換頁面 ↓"
          hint="計時 / 統計 / 目標 / 歷史 / 設定 — 整個 App 都會跟著主題變色">
          <InteractivePhone/>
        </Card>
      </Section>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
