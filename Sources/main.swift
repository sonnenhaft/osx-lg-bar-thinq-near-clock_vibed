import AppKit

if CommandLine.arguments.contains("--self-test") {
  precondition(degree(22) == "22°")
  precondition(degree(22.5) == "22.5°")
  precondition(
    celsius([["unit": "F", "currentTemperature": 72], ["unit": "C", "currentTemperature": 22]])[
      "currentTemperature"] as? Int == 22)
  precondition(equal(NSNumber(value: true), true))
  precondition(energyTotal(["result": ["usage": [["value": 100], ["value": 200]]]]) == 300)
  precondition(energyTotal(["result": ["usage": []]]) == nil)
  precondition(liveWatts(["energyUsage": 500]) == nil)
  precondition(liveWatts(["currentPower": 340]) == 340)
  precondition(intervals == [1, 5, 30, 60, 300, 600])
  precondition(
    energyTotal(["result": ["dataList": [["energyUsage": 750], ["energyUsage": 1250]]]]) == 2000)
  var queue = SelectionState()
  queue.enqueue([("fan", "speed", "LOW")])
  _ = queue.take()
  queue.enqueue([("fan", "speed", "MID")])
  queue.enqueue([("fan", "speed", "HIGH"), ("eco", "enabled", true)])
  precondition(queue.display("fan", "speed") as? String == "HIGH")
  queue.finishBatch()
  precondition(queue.take()?.count == 2)
  queue.recordSent(("fan", "speed", "HIGH"))
  queue.finishBatch()
  precondition(queue.display("fan", "speed") as? String == "HIGH")
  queue.confirm([("fan", "speed", "MID")])
  precondition(queue.needsConfirmation)
  queue.confirm([("fan", "speed", "HIGH")])
  precondition(!queue.needsConfirmation)
  var retry = AutoRetry()
  for _ in 0..<4 { retry.fail() }
  precondition(!retry.stopped)
  retry.fail()
  precondition(retry.stopped)
  let epoch = Date(timeIntervalSince1970: 0)
  let cache = WeekHistory(lastAttempt: Date(timeIntervalSince1970: 0))
  precondition(
    !cache.due(at: epoch.addingTimeInterval(3599)) && cache.due(at: epoch.addingTimeInterval(3600)))
  var utc = Calendar(identifier: .gregorian)
  utc.timeZone = TimeZone(secondsFromGMT: 0)!
  let days = WeekChart.series(
    response: [
      "result": [
        "dataList": [
          ["date": "19700107", "energyUsage": 0], ["date": "19700106", "energyUsage": 600],
        ]
      ]
    ], end: epoch.addingTimeInterval(6 * 86400), calendar: utc)
  precondition(days.count == 10 && days[9].wh == 0 && days[8].wh == 600 && days[7].wh == nil)
  let nine = epoch.addingTimeInterval(9 * 3600)
  let tomorrow = nine.addingTimeInterval(86400)
  var history = WeekHistory()
  for (t, wh) in [
    (nine.addingTimeInterval(-60), 99.0), (nine.addingTimeInterval(60), 101.0), (tomorrow, 150.0),
  ] {
    history.record(Boundary(time: t, wh: wh), calendar: utc)
  }
  let shifted = WeekChart.series(
    response: ["dataList": [["date": "19700101", "energyUsage": 800]]], end: epoch, calendar: utc,
    mornings: history.mornings ?? [:])
  precondition(
    shifted.last?.wh == 850 && shifted.last?.shifted == true && shifted.last?.estimated == true)
  let daily = WeekChart.series(
    response: [
      "dataList": [["date": "19700101", "energyUsage": 3600, "operationTimeMinutes": 120]]
    ], end: epoch, calendar: utc)
  precondition(daily.last?.seconds == 7200 && daily.last?.detail.contains("2h 0m") == true)
  var observed = ObservedUse()
  observed.sample(at: nine.addingTimeInterval(-30), on: true, interval: 60, calendar: utc)
  observed.sample(at: nine.addingTimeInterval(30), on: true, interval: 60, calendar: utc)
  precondition(observed.shifted["19691231"] == 30 && observed.shifted["19700101"] == 30)
  observed.sample(at: tomorrow, on: true, interval: 60, calendar: utc)
  precondition(observed.shifted["19700101"] == 30)
  let modeEco = EcoChoice(
    flag: nil, flagWrites: nil, writableFlag: false, mode: "COOL",
    modes: ["COOL", "ENERGY_SAVING"], returnMode: nil)
  precondition(modeEco.enabled == false && modeEco.change?.2 as? String == "ENERGY_SAVING")
  let ecoOff = EcoChoice(
    flag: nil, flagWrites: nil, writableFlag: false, mode: "ENERGY_SAVING",
    modes: ["COOL", "ENERGY_SAVING"], returnMode: nil)
  precondition(ecoOff.enabled == true && ecoOff.change?.2 as? String == "COOL")
  let boolEco = EcoChoice(
    flag: false, flagWrites: [true, false], writableFlag: true, mode: nil, modes: [],
    returnMode: nil)
  precondition(boolEco.change?.2 as? Bool == true)
  let emptyWeek = WeekChart.series(
    response: ["result": ["dataList": []]], end: epoch, calendar: utc)
  precondition(!emptyWeek.contains { $0.wh != nil })
  precondition(["LOW", "MID", "HIGH", "AUTO"].map { FanIndicator.count(for: $0) } == [1, 2, 3, 0])
  print("Core, command selection, retry and weekly history checks passed")
  exit(0)

}
MainActor.assumeIsolated {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  let delegate = App()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
}
