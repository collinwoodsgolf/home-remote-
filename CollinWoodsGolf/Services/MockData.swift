import Foundation

/// Sample content shaped exactly like real backend responses.
enum MockData {
    static func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    static let client = Client(
        id: "client-1",
        firstName: "Jordan",
        lastName: "Avery",
        email: "jordan@example.com",
        phone: "+1 (212) 555-0142",
        membership: .member,
        acuityClientID: "acuity-38291",
        ghinNumber: "1234567",
        homeClub: "Manhattan Woods",
        referralCode: "JORDAN-CWG"
    )

    static let appointmentTypes: [AppointmentType] = [
        AppointmentType(
            id: "type-1", name: "Swing Assessment",
            details: "Full video + Swing Catalyst pressure-plate assessment. The starting point for new students.",
            durationMinutes: 90, price: 450, location: AppConfig.homeBase,
            memberOnly: false, acuityAppointmentTypeID: 10001),
        AppointmentType(
            id: "type-2", name: "Coaching Session",
            details: "One-hour session at NEXUS — swing, short game, or putting based on your plan.",
            durationMinutes: 60, price: 300, location: AppConfig.homeBase,
            memberOnly: false, acuityAppointmentTypeID: 10002),
        AppointmentType(
            id: "type-3", name: "Member Session",
            details: "Included member coaching hour. Book as part of your program.",
            durationMinutes: 60, price: nil, location: AppConfig.homeBase,
            memberOnly: true, acuityAppointmentTypeID: 10003),
        AppointmentType(
            id: "type-4", name: "On-Course Playing Lesson",
            details: "Nine holes at Manhattan Woods focused on scoring, strategy, and decision-making.",
            durationMinutes: 180, price: nil, location: "Manhattan Woods Golf Club",
            memberOnly: true, acuityAppointmentTypeID: 10004),
    ]

    static let upcomingBookings: [Booking] = [
        Booking(
            id: "booking-1", appointmentTypeName: "Member Session",
            start: Calendar.current.date(byAdding: .day, value: 3, to: daysAgo(0, hour: 15))!,
            durationMinutes: 60, location: AppConfig.homeBase, acuityAppointmentID: 88231),
    ]

    static let lessons: [Lesson] = [
        Lesson(
            id: "lesson-3", date: daysAgo(6), title: "Driver: shallowing the transition",
            location: AppConfig.homeBase, focusAreas: ["Driver", "Transition"],
            note: LessonNote(
                summary: "Big step forward off the tee. We worked on starting the downswing from the ground up so the club shallows instead of steepening. Pressure trace on Swing Catalyst showed the lead-side shift happening earlier and smoother.",
                keyTakeaways: [
                    "Feel: trail shoulder stays 'closed' while pressure moves lead side",
                    "Club is shallowing ~4° more than last month",
                    "Miss to guard against is now a pull, not a slice",
                ],
                homework: [
                    "Step-change drill — 20 balls per range session",
                    "Pump drill in slow motion, 10 reps before every driver set",
                ],
                source: "Plaud AI", transcriptURL: nil),
            videos: [
                SwingVideo(
                    id: "video-5", title: "Driver — Down the Line", angle: "Down the Line",
                    url: URL(string: "https://storage.collinwoodsgolf.com/videos/lesson-3-dtl.mp4")!,
                    thumbnailURL: nil, capturedAt: daysAgo(6), source: "Swing Catalyst"),
                SwingVideo(
                    id: "video-6", title: "Driver — Face On", angle: "Face On",
                    url: URL(string: "https://storage.collinwoodsgolf.com/videos/lesson-3-fo.mp4")!,
                    thumbnailURL: nil, capturedAt: daysAgo(6), source: "Swing Catalyst"),
            ]),
        Lesson(
            id: "lesson-2", date: daysAgo(20), title: "Wedge distance control",
            location: AppConfig.homeBase, focusAreas: ["Wedges", "Scoring"],
            note: LessonNote(
                summary: "Built a three-length wedge system (clock drill) for the 60–110 yard window. Carry numbers were consistent within 5 yards by the end of the session.",
                keyTakeaways: [
                    "9 o'clock swing with 54° = 82 yards carry",
                    "Tempo, not effort, controls distance",
                ],
                homework: ["Clock drill ladder: 10 balls per length, log carries"],
                source: "Plaud AI", transcriptURL: nil),
            videos: [
                SwingVideo(
                    id: "video-3", title: "Wedge — Face On", angle: "Face On",
                    url: URL(string: "https://storage.collinwoodsgolf.com/videos/lesson-2-fo.mp4")!,
                    thumbnailURL: nil, capturedAt: daysAgo(20), source: "Swing Catalyst"),
            ]),
        Lesson(
            id: "lesson-1", date: daysAgo(41), title: "Initial assessment",
            location: AppConfig.homeBase, focusAreas: ["Assessment"],
            note: LessonNote(
                summary: "Baseline assessment. Strong grip with a steep transition producing a left miss under pressure. Great mobility for range of motion work. Plan: neutralize grip slightly, then sequence work.",
                keyTakeaways: [
                    "Baseline driver clubhead speed: 102 mph",
                    "Priority order: transition → wedge system → putting setup",
                ],
                homework: ["Grip checkpoints in mirror, 5 minutes daily"],
                source: "Plaud AI", transcriptURL: nil),
            videos: [
                SwingVideo(
                    id: "video-1", title: "Assessment — Down the Line", angle: "Down the Line",
                    url: URL(string: "https://storage.collinwoodsgolf.com/videos/lesson-1-dtl.mp4")!,
                    thumbnailURL: nil, capturedAt: daysAgo(41), source: "Swing Catalyst"),
            ]),
    ]

    static let coachThread: [ChatMessage] = [
        ChatMessage(id: "cm-1", channel: .coach, isFromClient: false,
                    text: "Great session yesterday — the driver numbers were the best we've seen. Notes and videos are in your lesson history.",
                    sentAt: daysAgo(5, hour: 9)),
        ChatMessage(id: "cm-2", channel: .coach, isFromClient: true,
                    text: "Felt great. Sticking with the step-change drill this week.",
                    sentAt: daysAgo(5, hour: 12)),
        ChatMessage(id: "cm-3", channel: .coach, isFromClient: false,
                    text: "Perfect. Send me a face-on video after your next range session and I'll take a look.",
                    sentAt: daysAgo(5, hour: 13)),
    ]

    static let caddieThread: [ChatMessage] = [
        ChatMessage(id: "ai-1", channel: .caddie, isFromClient: false,
                    text: "Welcome back, Jordan. Since your last lesson you've been working on shallowing the driver transition. Want a practice plan for this week, or help thinking through your round at Manhattan Woods on Saturday?",
                    sentAt: daysAgo(1, hour: 8)),
    ]

    static func caddieReply(to text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("driver") || lower.contains("slice") || lower.contains("tee") {
            return "From your lesson notes, your driver work is about starting the downswing from the ground up — and your miss has moved from a slice to an occasional pull, which is progress. Coach Woods gave you the step-change drill (20 balls) and slow-motion pump drill (10 reps). On the course, favor the left edge of the fairway window and let the pull be your guard-rail miss."
        }
        if lower.contains("wedge") || lower.contains("100") || lower.contains("distance") {
            return "Your wedge system from the March session: 9 o'clock with the 54° carries 82 yards, and tempo — not effort — controls distance. For the 60–110 window, pick the length first, then the club. Want me to lay out a 30-minute wedge ladder for your next practice session?"
        }
        if lower.contains("plan") || lower.contains("practice") {
            return "Here's a 45-minute plan built from your current priorities:\n\n1. Pump drill, slow motion — 10 reps (transition feel)\n2. Step-change drill — 20 drivers\n3. Clock-drill wedge ladder — 10 balls × 3 lengths, log carries\n4. Finish: 9 putts from 3/6/9 feet\n\nYour handicap is trending down (8.4 → 7.2 in three months) — the scoring gains are coming from inside 110 yards, so keep the wedge block in every session."
        }
        return "Good question. Based on what I know about your game — 7.2 index, driver transition work in progress, wedge system dialed inside 110 yards — I'd tie this back to your current plan. Ask me about your driver, wedges, or a practice plan, and I'll use your lesson history to get specific."
    }

    static let memoryFacts: [GameMemoryFact] = [
        GameMemoryFact(id: "mem-1", fact: "Handicap index 7.2, trending down from 8.4 in April", learnedAt: daysAgo(3), category: "Goals"),
        GameMemoryFact(id: "mem-2", fact: "Working on shallowing driver transition; miss has moved from slice to pull", learnedAt: daysAgo(6), category: "Swing"),
        GameMemoryFact(id: "mem-3", fact: "Wedge clock system: 9 o'clock 54° = 82 yards carry", learnedAt: daysAgo(20), category: "Tendencies"),
        GameMemoryFact(id: "mem-4", fact: "Plays most rounds at Manhattan Woods; firm, fast greens", learnedAt: daysAgo(30), category: "Courses"),
        GameMemoryFact(id: "mem-5", fact: "Goal: single-digit index maintained through the season, break 75 at home course", learnedAt: daysAgo(41), category: "Goals"),
    ]

    static let drills: [Drill] = [
        Drill(id: "drill-1", title: "Step-Change Drill", category: "Driver",
              details: "Start with feet together, step toward the target as the club swings back. Trains ground-up sequencing in transition.",
              durationMinutes: 10, videoURL: nil, thumbnailURL: nil),
        Drill(id: "drill-2", title: "Slow-Motion Pump Drill", category: "Driver",
              details: "Three slow pumps to the delivery position, then swing. Grooves the shallowing move without ball-flight pressure.",
              durationMinutes: 5, videoURL: nil, thumbnailURL: nil),
        Drill(id: "drill-3", title: "Clock-Drill Wedge Ladder", category: "Short Game",
              details: "Three backswing lengths (7:30 / 9:00 / 10:30) with one wedge. Log carry distances to build your personal chart.",
              durationMinutes: 15, videoURL: nil, thumbnailURL: nil),
        Drill(id: "drill-4", title: "Gate Putting — Start Line", category: "Putting",
              details: "Two tees just wider than the putter head, a ball-width gate 18 inches down the line. Ten in a row through both gates.",
              durationMinutes: 10, videoURL: nil, thumbnailURL: nil),
        Drill(id: "drill-5", title: "Hip Mobility Openers", category: "Fitness",
              details: "90/90 transitions and standing hip CARs before practice. Protects the lead hip and unlocks rotation.",
              durationMinutes: 8, videoURL: nil, thumbnailURL: nil),
    ]

    static let handicapHistory: [HandicapEntry] = [
        HandicapEntry(date: daysAgo(150), index: 8.9, source: "GHIN"),
        HandicapEntry(date: daysAgo(120), index: 8.4, source: "GHIN"),
        HandicapEntry(date: daysAgo(90), index: 8.1, source: "GHIN"),
        HandicapEntry(date: daysAgo(60), index: 7.8, source: "GHIN"),
        HandicapEntry(date: daysAgo(30), index: 7.5, source: "GHIN"),
        HandicapEntry(date: daysAgo(7), index: 7.2, source: "GHIN"),
    ]

    static let rounds: [RoundSummary] = [
        RoundSummary(id: "round-1", date: daysAgo(4), course: "Manhattan Woods", score: 79, toPar: 7, source: "GHIN"),
        RoundSummary(id: "round-2", date: daysAgo(11), course: "Manhattan Woods", score: 82, toPar: 10, source: "Arccos"),
        RoundSummary(id: "round-3", date: daysAgo(18), course: "Bethpage Black", score: 88, toPar: 17, source: "GHIN"),
        RoundSummary(id: "round-4", date: daysAgo(25), course: "Manhattan Woods", score: 80, toPar: 8, source: "TheGrint"),
    ]

    static let integrations: [IntegrationConnection] = [
        IntegrationConnection(provider: .ghin, isConnected: true, accountLabel: "GHIN #1234567", lastSyncedAt: daysAgo(0, hour: 6)),
        IntegrationConnection(provider: .arccos, isConnected: true, accountLabel: "jordan@example.com", lastSyncedAt: daysAgo(1, hour: 22)),
        IntegrationConnection(provider: .upgame, isConnected: false, accountLabel: nil, lastSyncedAt: nil),
        IntegrationConnection(provider: .theGrint, isConnected: false, accountLabel: nil, lastSyncedAt: nil),
    ]

    static func referralStatus(code: String) -> ReferralStatus {
        ReferralStatus(
            code: code,
            invitesSent: 4,
            lessonsBooked: 2,
            rewardsEarned: "1 complimentary session",
            pending: [
                ReferralInvite(id: "ref-1", name: "Sam Whitfield", status: "Booked first lesson", date: daysAgo(12)),
                ReferralInvite(id: "ref-2", name: "Priya Nair", status: "Invited", date: daysAgo(5)),
            ])
    }
}
