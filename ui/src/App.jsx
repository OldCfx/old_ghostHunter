import React, { useState, useEffect, useRef, useMemo } from 'react'
import { GiGhost } from 'react-icons/gi'
import introSound from './sounds/quest_intro.mp3'

const imageModules = import.meta.glob('./screamers/*.{png,jpg,jpeg,webp}', { eager: true })
const audioModules = import.meta.glob('./screamers/*.{mp3,ogg,wav}', { eager: true })

const isEnvBrowser = !('invokeNative' in window)

export default function App() {
  const [hudData, setHudData] = useState({
    visible: isEnvBrowser,
    current: isEnvBrowser ? 1 : 0,
    total: isEnvBrowser ? 3 : 0
  })
  const [userHidden, setUserHidden] = useState(false)
  const [activeScreamer, setActiveScreamer] = useState(null)

  const audioRef = useRef(null)
  const screamerAudioRef = useRef(null)

  const screamers = useMemo(() => {
    const list = []
    const baseNames = new Set()

    for (const path in imageModules) {
      const name = path.replace(/^.*[\\/]/, '').replace(/\.[^/.]+$/, '')
      baseNames.add(name)
    }

    baseNames.forEach((name) => {
      let imageSrc = null
      let audioSrc = null

      for (const path in imageModules) {
        if (path.includes(`/${name}.`)) {
          imageSrc = imageModules[path].default || imageModules[path]
          break
        }
      }

      for (const path in audioModules) {
        if (path.includes(`/${name}.`)) {
          audioSrc = audioModules[path].default || audioModules[path]
          break
        }
      }

      if (imageSrc && audioSrc) {
        list.push({ id: name, image: imageSrc, sound: audioSrc })
      }
    })

    return list
  }, [])

  const handleIntroAudioEnded = () => {
    if (!isEnvBrowser) {
      fetch(`https://${GetParentResourceName()}/audioFinished`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({})
      }).catch(() => { })
    }
  }

  const handleScreamerAudioEnded = () => {
    setActiveScreamer(null)
  }

  const triggerRandomScreamer = () => {
    if (screamers.length === 0) return

    const randomScreamer = screamers[Math.floor(Math.random() * screamers.length)]
    setActiveScreamer(randomScreamer.image)

    if (screamerAudioRef.current) {
      screamerAudioRef.current.src = randomScreamer.sound
      screamerAudioRef.current.currentTime = 0
      screamerAudioRef.current.play().catch(() => {
        setActiveScreamer(null)
      })
    }
  }

  useEffect(() => {
    const handleMessage = (event) => {
      const { action, current, total, visible } = event.data

      if (action === 'updateHud') {
        setHudData({
          visible: visible ?? true,
          current: current ?? 0,
          total: total ?? 0
        })
      } else if (action === 'toggleHud') {
        setUserHidden((prev) => !prev)
      } else if (action === 'playIntroAudio') {
        if (audioRef.current) {
          audioRef.current.currentTime = 0
          audioRef.current.play().catch(() => {
            handleIntroAudioEnded()
          })
        }
      } else if (action === 'playRandomScreamer') {
        triggerRandomScreamer()
      }
    }

    const handleKeyDown = (event) => {
      if (isEnvBrowser && (event.key === 'h' || event.key === 'H')) {
        setUserHidden((prev) => !prev)
      }
    }

    window.addEventListener('message', handleMessage)
    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('message', handleMessage)
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [screamers])

  const isVisible = hudData.visible && !userHidden

  return (
    <>
      {isEnvBrowser && <div className="browser-preview" />}

      <audio
        ref={audioRef}
        src={introSound}
        preload="auto"
        onEnded={handleIntroAudioEnded}
      />

      <audio
        ref={screamerAudioRef}
        preload="auto"
        onEnded={handleScreamerAudioEnded}
      />

      {activeScreamer && (
        <div className="screamer-overlay">
          <img src={activeScreamer} alt="screamer" className="screamer-image" />
        </div>
      )}

      <div className={`hud-panel ${isVisible ? '' : 'hud-hidden'}`}>
        <div className="hud-header">
          <div className="hud-title-wrap">
            <span className="hud-icon">
              <GiGhost />
            </span>
            <span className="hud-title">Chasseur de fantômes</span>
          </div>
          <span className="key-badge">H</span>
        </div>

        <div className="hud-body">
          <span className="hud-label">Fantômes</span>
          <div className="hud-counter">
            <span>{hudData.current}</span> / {hudData.total}
          </div>
        </div>
      </div>

      {isEnvBrowser && (
        <div className="dev-controls">
          <button onClick={() => setUserHidden((prev) => !prev)}>
            Toggle HUD (H)
          </button>
          <button
            onClick={() =>
              setHudData((prev) => ({
                ...prev,
                current: Math.min(prev.current + 1, prev.total)
              }))
            }
          >
            +1 Fantôme
          </button>
          <button
            onClick={() =>
              setHudData((prev) => ({
                ...prev,
                current: 0
              }))
            }
          >
            Reset Compteur
          </button>
          <button
            onClick={() => {
              if (audioRef.current) {
                audioRef.current.currentTime = 0
                audioRef.current.play()
              }
            }}
          >
            Test Audio Intro
          </button>
          <button onClick={triggerRandomScreamer}>
            Test Screamer Auto ({screamers.length} dispo)
          </button>
        </div>
      )}
    </>
  )
}