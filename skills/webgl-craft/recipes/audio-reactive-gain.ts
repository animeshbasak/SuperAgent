/**
 * AUDIO-REACTIVE GAIN — Web Audio gain modulated by scroll velocity
 *
 * Source lineage:
 *   Pattern used in Igloo Inc, Prometheus Fuels, and other cinematic sites.
 *   Combines Web Audio API's GainNode with Lenis scroll velocity to produce
 *   ambient audio that responds to user motion without being gimmicky.
 *
 * When to use:
 *   - Sites where ambient sound is part of the experience and scroll is the
 *     primary input.
 *   - Subjects where audio response reinforces the narrative (space, speed,
 *     growth, tension).
 *
 * When NOT to use:
 *   - Content-heavy sites where audio distracts from reading.
 *   - Sites without a clear "why does this have sound" answer. Ambient audio
 *     without purpose is noise.
 *
 * Edit points:
 *   - baseVolume: the resting volume (0.2–0.4 typical).
 *   - velocityMultiplier: how much scroll affects volume.
 *   - fadeTime: ramp duration for volume changes (not too fast — avoid pumping).
 *   - crossfadeOverlap: overlap for seamless loop.
 *
 * Known trade-offs:
 *   - Requires user gesture to start (browser autoplay policy). Always
 *     present a mute/unmute toggle; never autoplay without user consent.
 *   - Mobile Safari has quirks with Web Audio suspend/resume; test thoroughly.
 *   - Accessibility: provide a prominent, keyboard-reachable mute toggle.
 */

export interface AudioReactiveGainOptions {
  audioUrl: string
  baseVolume?: number
  maxVolume?: number
  velocityMultiplier?: number
  fadeTime?: number
  crossfadeOverlap?: number
  /** Optional: function returning current scroll velocity (e.g., lenis.velocity) */
  getVelocity?: () => number
}

export class AudioReactiveGain {
  private ctx: AudioContext
  private gainNode: GainNode
  private sourceA: AudioBufferSourceNode | null = null
  private sourceB: AudioBufferSourceNode | null = null
  private buffer: AudioBuffer | null = null
  private isPlaying = false
  private isMuted = true
  private baseVolume: number
  private maxVolume: number
  private velocityMultiplier: number
  private fadeTime: number
  private crossfadeOverlap: number
  private getVelocity: () => number
  private rafHandle: number | null = null

  constructor(opts: AudioReactiveGainOptions) {
    this.baseVolume = opts.baseVolume ?? 0.3
    this.maxVolume = opts.maxVolume ?? 0.6
    this.velocityMultiplier = opts.velocityMultiplier ?? 0.005
    this.fadeTime = opts.fadeTime ?? 0.4
    this.crossfadeOverlap = opts.crossfadeOverlap ?? 0.5
    this.getVelocity = opts.getVelocity ?? (() => 0)

    this.ctx = new (window.AudioContext ||
      (window as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext)()
    this.gainNode = this.ctx.createGain()
    this.gainNode.gain.value = 0
    this.gainNode.connect(this.ctx.destination)

    this.loadBuffer(opts.audioUrl)

    // Restore mute state from localStorage
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('audioMuted')
      this.isMuted = saved === null ? true : saved === 'true'
    }

    // Pause when tab is hidden
    document.addEventListener('visibilitychange', this.onVisibilityChange)
  }

  private async loadBuffer(url: string) {
    try {
      const res = await fetch(url)
      const arrayBuffer = await res.arrayBuffer()
      this.buffer = await this.ctx.decodeAudioData(arrayBuffer)
    } catch (e) {
      console.warn('Audio load failed', e)
    }
  }

  private onVisibilityChange = () => {
    if (document.hidden) {
      this.fadeTo(0, 0.3)
    } else if (!this.isMuted) {
      this.fadeTo(this.baseVolume, 0.3)
    }
  }

  private createSource(): AudioBufferSourceNode | null {
    if (!this.buffer) return null
    const source = this.ctx.createBufferSource()
    source.buffer = this.buffer
    source.loop = true
    source.connect(this.gainNode)
    return source
  }

  private fadeTo(value: number, duration = this.fadeTime) {
    const now = this.ctx.currentTime
    this.gainNode.gain.cancelScheduledValues(now)
    this.gainNode.gain.setValueAtTime(this.gainNode.gain.value, now)
    this.gainNode.gain.linearRampToValueAtTime(value, now + duration)
  }

  /**
   * Start audio playback. MUST be called in a user gesture handler
   * (click, tap, keypress) due to browser autoplay policies.
   */
  async start() {
    if (this.isPlaying) return

    if (this.ctx.state === 'suspended') {
      await this.ctx.resume()
    }

    this.sourceA = this.createSource()
    if (!this.sourceA) {
      // Buffer not yet loaded; retry shortly
      setTimeout(() => this.start(), 200)
      return
    }

    this.sourceA.start(0)
    this.isPlaying = true

    if (!this.isMuted) {
      this.fadeTo(this.baseVolume)
    }

    // Start the reactivity loop
    this.startReactivityLoop()
  }

  private startReactivityLoop() {
    const update = () => {
      if (!this.isMuted) {
        const velocity = Math.abs(this.getVelocity())
        const targetVolume = Math.min(
          this.maxVolume,
          this.baseVolume + velocity * this.velocityMultiplier
        )

        // Only ramp if significantly different (avoid excessive scheduling)
        if (Math.abs(this.gainNode.gain.value - targetVolume) > 0.01) {
          this.fadeTo(targetVolume, 0.15)
        }
      }
      this.rafHandle = requestAnimationFrame(update)
    }
    this.rafHandle = requestAnimationFrame(update)
  }

  toggleMute() {
    this.isMuted = !this.isMuted
    localStorage.setItem('audioMuted', String(this.isMuted))
    this.fadeTo(this.isMuted ? 0 : this.baseVolume)
  }

  getMuted(): boolean {
    return this.isMuted
  }

  dispose() {
    if (this.rafHandle !== null) {
      cancelAnimationFrame(this.rafHandle)
    }
    document.removeEventListener('visibilitychange', this.onVisibilityChange)
    this.sourceA?.stop()
    this.sourceB?.stop()
    this.ctx.close()
  }
}

// ============================================================================
// REACT USAGE
// ============================================================================

/*
'use client'

import { useEffect, useRef, useState } from 'react'
import { AudioReactiveGain } from './audio-reactive-gain'
// Assume you have a Lenis instance accessible somewhere
import { lenis } from '@/lib/lenis'

export function AudioToggle() {
  const audioRef = useRef<AudioReactiveGain | null>(null)
  const [muted, setMuted] = useState(true)

  useEffect(() => {
    audioRef.current = new AudioReactiveGain({
      audioUrl: '/audio/ambient.m4a',
      baseVolume: 0.3,
      maxVolume: 0.55,
      velocityMultiplier: 0.004,
      getVelocity: () => lenis?.velocity ?? 0,
    })

    setMuted(audioRef.current.getMuted())

    return () => audioRef.current?.dispose()
  }, [])

  const handleClick = async () => {
    if (!audioRef.current) return

    // First click: start playback (user gesture required)
    await audioRef.current.start()
    audioRef.current.toggleMute()
    setMuted(audioRef.current.getMuted())
  }

  return (
    <button
      onClick={handleClick}
      aria-label={muted ? 'Unmute ambient audio' : 'Mute ambient audio'}
      aria-pressed={!muted}
      className="audio-toggle"
    >
      {muted ? '🔇' : '🔊'}
    </button>
  )
}
*/

// ============================================================================
// CROSSFADE-OVERLAP VARIANT (for loops with audible seams)
// ============================================================================
//
// If the ambient loop has an audible seam at the boundary, schedule a
// second source to start before the first ends, with a fade crossover:
//
//   const duration = this.buffer.duration
//   const overlap = this.crossfadeOverlap
//
//   this.sourceA = this.createSource()
//   this.sourceA.start(0)
//
//   const secondStartTime = this.ctx.currentTime + duration - overlap
//   this.sourceB = this.createSource()
//   this.sourceB.start(secondStartTime)
//
//   // Then schedule periodic swap back and forth...
//
// This is rarely needed — well-authored ambient loops don't have audible
// seams. If yours does, re-export the source audio with a proper loop
// point rather than adding crossfade logic.

// ============================================================================
// REDUCED-MOTION AND REDUCED-AUDIO
// ============================================================================
//
// prefers-reduced-motion doesn't directly govern audio, but many users who
// set reduced motion also want reduced sensory input overall. A reasonable
// heuristic: if prefers-reduced-motion is set, skip the scroll-reactivity
// (just play at base volume) and hide the visualizer if any.
//
//   const prefersReducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches
//   const opts: AudioReactiveGainOptions = {
//     audioUrl: '/audio/ambient.m4a',
//     velocityMultiplier: prefersReducedMotion ? 0 : 0.004,
//     // ...
//   }

// ============================================================================
// SOURCING AMBIENT AUDIO
// ============================================================================
//
// - Freesound (CC0 and CC-BY, search "ambient drone loop").
// - Pixabay Music (free commercial use).
// - Uppbeat (free tier with attribution).
// - Splice (sample library; good if you're assembling your own loop).
//
// Avoid any source that requires "license inquiry" or custom terms —
// that's legal exposure.
//
// Aim for a loop of 15–45 seconds, AAC compressed at 128kbps, under 1MB.
