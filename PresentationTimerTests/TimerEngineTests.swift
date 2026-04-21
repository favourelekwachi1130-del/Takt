import XCTest
@testable import PresentationTimer

final class TimerEngineTests: XCTestCase {
    func testStartAndProgress() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        XCTAssertEqual(engine.runState, .running)
        XCTAssertEqual(engine.currentSegmentIndex, 0)
        let cues = engine.tick(now: Date().addingTimeInterval(10))
        XCTAssertTrue(cues.isEmpty)
        XCTAssertEqual(engine.elapsedInCurrentSegment, 10, accuracy: 0.01)
    }

    func testFirstCueAtHalfSegment() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)], firstCueFraction: 0.5)
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(51))
        XCTAssertTrue(cues.contains(.threeQuarter(segmentIndex: 0)))
    }

    func testThreeQuarterCue() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(76))
        let kinds = cues.compactMap { c -> String? in
            if case .threeQuarter = c { return "q" }
            if case .segmentEnd = c { return "e" }
            if case .sessionComplete = c { return "s" }
            return nil
        }
        XCTAssertTrue(kinds.contains("q"))
    }

    func testSegmentEndAndSessionComplete() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "Only", durationSeconds: 10)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(11))
        XCTAssertTrue(cues.contains(.segmentEnd(segmentIndex: 0)))
        XCTAssertTrue(cues.contains(.sessionComplete))
        XCTAssertEqual(engine.runState, .completed)
    }

    func testMultiSegmentCarryOverflow() {
        let engine = TimerEngine()
        let preset = Preset(
            name: "T",
            segments: [
                Segment(title: "A", durationSeconds: 10),
                Segment(title: "B", durationSeconds: 20)
            ]
        )
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        _ = engine.tick(now: t0.addingTimeInterval(25))
        XCTAssertEqual(engine.currentSegmentIndex, 1)
        // 25s total: 10s on first segment, 15s elapsed on second.
        XCTAssertEqual(engine.elapsedInCurrentSegment, 15, accuracy: 0.05)
        XCTAssertEqual(engine.runState, .running)
    }

    func testPauseResume() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        _ = engine.tick(now: t0.addingTimeInterval(30))
        engine.pause()
        XCTAssertEqual(engine.runState, .paused)
        let elapsedAfterPause = engine.elapsedInCurrentSegment
        engine.resume()
        let tResume = Date()
        _ = engine.tick(now: tResume.addingTimeInterval(10))
        XCTAssertEqual(engine.elapsedInCurrentSegment, elapsedAfterPause + 10, accuracy: 0.25)
    }

    func testEmptyPresetDoesNotStart() {
        let engine = TimerEngine()
        engine.loadPreset(Preset(name: "E", segments: []))
        engine.start()
        XCTAssertEqual(engine.runState, .idle)
    }

    func testCompletedSegmentActualsRecorded() {
        let engine = TimerEngine()
        let preset = Preset(
            name: "T",
            segments: [
                Segment(title: "A", durationSeconds: 10),
                Segment(title: "B", durationSeconds: 20)
            ]
        )
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        _ = engine.tick(now: t0.addingTimeInterval(10))
        XCTAssertEqual(engine.completedSegmentActualElapsed.count, 1)
        XCTAssertEqual(engine.completedSegmentActualElapsed[0], 10, accuracy: 0.05)
        XCTAssertEqual(engine.currentSegmentIndex, 1)
    }
}

