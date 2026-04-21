import XCTest
@testable import PresentationTimer

final class TimerEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let d = UserDefaults.standard
        d.set(0.75, forKey: TaktUserSettings.firstCueFractionKey)
        d.set(0.9, forKey: TaktUserSettings.secondCueFractionKey)
    }

    override func tearDown() {
        let d = UserDefaults.standard
        d.removeObject(forKey: TaktUserSettings.firstCueFractionKey)
        d.removeObject(forKey: TaktUserSettings.secondCueFractionKey)
        super.tearDown()
    }

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
        UserDefaults.standard.set(0.5, forKey: TaktUserSettings.firstCueFractionKey)
        UserDefaults.standard.set(0.85, forKey: TaktUserSettings.secondCueFractionKey)
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(51))
        XCTAssertTrue(cues.contains(.firstPacing(segmentIndex: 0)))
    }

    func testFirstCueDefaultTiming() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(76))
        let kinds = cues.compactMap { c -> String? in
            if case .firstPacing = c { return "f" }
            if case .secondPacing = c { return "s" }
            if case .segmentEnd = c { return "e" }
            if case .sessionComplete = c { return "c" }
            return nil
        }
        XCTAssertTrue(kinds.contains("f"))
    }

    func testSecondCueFires() {
        let engine = TimerEngine()
        let preset = Preset(name: "T", segments: [Segment(title: "A", durationSeconds: 100)])
        engine.loadPreset(preset)
        engine.start()
        let t0 = Date()
        let cues = engine.tick(now: t0.addingTimeInterval(91))
        XCTAssertTrue(cues.contains(.secondPacing(segmentIndex: 0)))
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
