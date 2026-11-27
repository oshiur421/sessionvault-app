/// A single recorded class/meeting session.
///
/// Mirrors the web app's Session type (src/app/data.ts). Sessions are stored
/// as JSON + a .md file in local app storage — never in Supabase.
class Session {
  Session({
    required this.id,
    required this.title,
    required this.subject,
    required this.category,
    required this.date,
    required this.time,
    required this.duration,
    required this.durationMin,
    required this.filename,
    required this.language,
    required this.tokens,
    required this.summary,
    required this.examHints,
    required this.notes,
    required this.actions,
    List<bool>? checkedActions,
    this.audioPaths = const [],
    this.summaryReady = false,
  }) : checkedActions =
            checkedActions ?? List<bool>.filled(actions.length, false);

  final String id;
  final String title;
  final String subject;
  final String category; // "Class" or "Meeting"
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String duration; // display, e.g. "1h 42m" or "08:13"
  final int durationMin;
  final String filename;
  final String language;
  final int tokens;
  final String summary;
  final List<ExamHint> examHints;
  final List<NoteSection> notes;
  final List<String> actions;
  final List<bool> checkedActions;
  final List<String> audioPaths; // chunk audio files for this session
  final bool summaryReady;

  Session copyWith({
    String? summary,
    List<ExamHint>? examHints,
    List<NoteSection>? notes,
    List<String>? actions,
    List<bool>? checkedActions,
    bool? summaryReady,
  }) {
    final a = actions ?? this.actions;
    return Session(
      id: id,
      title: title,
      subject: subject,
      category: category,
      date: date,
      time: time,
      duration: duration,
      durationMin: durationMin,
      filename: filename,
      language: language,
      tokens: tokens,
      summary: summary ?? this.summary,
      examHints: examHints ?? this.examHints,
      notes: notes ?? this.notes,
      actions: a,
      checkedActions: checkedActions ??
          (this.checkedActions.length == a.length
              ? this.checkedActions
              : List<bool>.filled(a.length, false)),
      audioPaths: audioPaths,
      summaryReady: summaryReady ?? this.summaryReady,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'category': category,
        'date': date,
        'time': time,
        'duration': duration,
        'durationMin': durationMin,
        'filename': filename,
        'language': language,
        'tokens': tokens,
        'summary': summary,
        'examHints': examHints.map((h) => h.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'actions': actions,
        'checkedActions': checkedActions,
        'audioPaths': audioPaths,
        'summaryReady': summaryReady,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String,
        category: j['category'] as String,
        date: j['date'] as String,
        time: j['time'] as String,
        duration: j['duration'] as String,
        durationMin: (j['durationMin'] as num).toInt(),
        filename: j['filename'] as String,
        language: j['language'] as String,
        tokens: (j['tokens'] as num).toInt(),
        summary: j['summary'] as String,
        examHints: (j['examHints'] as List)
            .map((e) => ExamHint.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: (j['notes'] as List)
            .map((e) => NoteSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        actions: List<String>.from(j['actions'] as List),
        checkedActions: j['checkedActions'] == null
            ? null
            : List<bool>.from(j['checkedActions'] as List),
        audioPaths: j['audioPaths'] == null
            ? const []
            : List<String>.from(j['audioPaths'] as List),
        summaryReady: j['summaryReady'] as bool? ?? false,
      );

  /// The structured Markdown file for this session — same shape as the web
  /// app's buildRaw().
  String buildRaw() {
    final lines = <String>[
      '---',
      'date: $date',
      'time: $time',
      'category: $category',
      'subject: $subject',
      'duration: $duration',
      'language: $language',
      '---',
      '',
      '# $title',
      '',
      '## Summary',
      '',
      summary,
      '',
      '## Exam hints and key takeaways',
      '',
      ...examHints.map((h) => '- [${h.time}] ${h.text}'),
      '',
      '## Structured notes',
      '',
      ...notes.expand((n) => [
            '### ${n.heading}',
            '',
            ...n.points.map((p) => '- $p'),
            '',
          ]),
      '## Action items',
      '',
      ...actions.map((a) => '- [ ] $a'),
      '',
    ];
    return lines.join('\n');
  }
}

class ExamHint {
  ExamHint({required this.time, required this.text});
  final String time;
  final String text;

  Map<String, dynamic> toJson() => {'time': time, 'text': text};
  factory ExamHint.fromJson(Map<String, dynamic> j) =>
      ExamHint(time: j['time'] as String, text: j['text'] as String);
}

class NoteSection {
  NoteSection({required this.heading, required this.points});
  final String heading;
  final List<String> points;

  Map<String, dynamic> toJson() =>
      {'heading': heading, 'points': points};
  factory NoteSection.fromJson(Map<String, dynamic> j) => NoteSection(
        heading: j['heading'] as String,
        points: List<String>.from(j['points'] as List),
      );
}

/// Token estimate used across Sessions/Merge (same rule as the web app:
/// roughly 23 tokens per minute of audio, minimum 150).
int estimateTokens(int durationMin) =>
    durationMin * 23 < 150 ? 150 : durationMin * 23;

/// Format seconds as MM:SS (under an hour) or H:MM:SS.
String fmtDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// The four sample sessions from the web demo, seeded on first launch.
List<Session> sampleSessions() => [
      Session(
        id: 'cis313-astar',
        title: 'CIS313 — A* Search & Admissibility',
        subject: 'CIS313',
        category: 'Class',
        date: '2026-11-26',
        time: '10:30',
        duration: '1h 42m',
        durationMin: 102,
        filename: '2026-11-26_10-30_CIS313_AI.md',
        language: 'Banglish',
        tokens: 2340,
        summary:
            'Sir covered A* search from the ground up: how the f(n) = g(n) + h(n) evaluation function works, why admissibility of the heuristic decides whether A* stays optimal, and where greedy best-first search fails. The class worked through a route-finding example on the board and compared A* with uniform-cost search and greedy search on the same graph.',
        examHints: [
          ExamHint(
              time: '00:12:40',
              text:
                  "Sir said 'exam-e asbe' — prove why A* is optimal when h(n) is admissible."),
          ExamHint(
              time: '00:38:05',
              text:
                  'Remember the difference between admissible and consistent heuristics — he repeated it twice.'),
          ExamHint(
              time: '01:05:22',
              text:
                  'The Romania map example: be ready to run A* step by step and show the frontier.'),
        ],
        notes: [
          NoteSection(heading: 'A* evaluation function', points: [
            'f(n) = g(n) + h(n) — g(n) is the cost so far, h(n) is the estimated cost to the goal.',
            'A* picks the node with the lowest f(n) from the frontier every time.',
            'Banglish note: sir bollo, g(n) ta holo already khoroch, h(n) ta holo andaz.',
          ]),
          NoteSection(heading: 'Admissibility and consistency', points: [
            'A heuristic is admissible if it never overestimates the true cost to the goal.',
            'A consistent heuristic also satisfies h(n) ≤ c(n, a, n′) + h(n′) for every action.',
            'Every consistent heuristic is admissible, but not every admissible heuristic is consistent.',
          ]),
          NoteSection(heading: 'A* vs greedy best-first search', points: [
            'Greedy uses only h(n), so it is fast but can take a bad path and is not optimal.',
            'Uniform-cost search uses only g(n) — optimal, but explores a lot.',
            'A* balances both, and stays optimal with an admissible heuristic.',
          ]),
        ],
        actions: [
          'Solve the Romania map A* trace by hand and compare with the class solution.',
          'Write the admissibility proof in your own words before the next class.',
          'Revise the greedy vs A* comparison table for the exam.',
        ],
        summaryReady: true,
      ),
      Session(
        id: 'cis321-mapreduce',
        title: 'CIS321 — MapReduce & Spark Partitioning',
        subject: 'CIS321',
        category: 'Class',
        date: '2026-11-25',
        time: '14:00',
        duration: '1h 28m',
        durationMin: 88,
        filename: '2026-11-25_14-00_CIS321_MapReduce.md',
        language: 'Banglish',
        tokens: 1760,
        summary:
            'The class walked through MapReduce end to end — map, shuffle, sort and reduce — then moved to Spark: RDDs, transformations vs actions, and why partitioning decides whether a job is fast or slow. Sir showed a word-count job and a skewed-key example where one reducer did almost all the work.',
        examHints: [
          ExamHint(
              time: '00:09:15',
              text:
                  "Sir said 'mone rakho' — shuffle is the most expensive phase of MapReduce."),
          ExamHint(
              time: '00:47:30',
              text:
                  'Likely exam question: why does data skew break partitioning, and how do you fix it?'),
          ExamHint(
              time: '01:12:00',
              text:
                  'Transformations are lazy, actions trigger execution — he asked this in the last quiz too.'),
        ],
        notes: [
          NoteSection(heading: 'MapReduce phases', points: [
            'Map: input splits turn into key-value pairs.',
            'Shuffle and sort: pairs with the same key are grouped together and sent to one reducer.',
            'Reduce: each reducer aggregates its group into the final output.',
          ]),
          NoteSection(heading: 'Spark RDDs', points: [
            'Transformations (map, filter) are lazy — they only build the plan.',
            'Actions (collect, count, save) actually run the job.',
            'Sir bollo, lazy evaluation na thakle Spark eto fast hoto na.',
          ]),
          NoteSection(heading: 'Partitioning and skew', points: [
            'Good partitioning spreads keys evenly across workers.',
            'A hot key sends most data to one reducer — that worker becomes the bottleneck.',
            'Fixes discussed: salting the key, repartitioning, and using a combiner.',
          ]),
        ],
        actions: [
          'Re-run the word-count example and note the shuffle output size.',
          'Write three lines on how salting fixes a skewed key.',
          'Revise lazy vs eager execution before the lab.',
        ],
        summaryReady: true,
      ),
      Session(
        id: 'meeting-capture',
        title: 'Mobile Capture & Offline Queue Sync',
        subject: 'Meetings',
        category: 'Meeting',
        date: '2026-11-24',
        time: '16:00',
        duration: '54m',
        durationMin: 54,
        filename: '2026-11-24_16-00_Meeting_Capture_Sync.md',
        language: 'Banglish',
        tokens: 1240,
        summary:
            'Team meeting on the mobile capture flow: recording must keep working when the phone goes offline, and the upload queue must sync in order once the network returns. Decisions: local-first storage, a retry queue with backoff, and no recording may be dropped silently — every failed upload shows in the queue.',
        examHints: [
          ExamHint(
              time: '00:18:20',
              text:
                  'Decision: offline recordings are never deleted until the sync confirms success.'),
          ExamHint(
              time: '00:35:10',
              text:
                  'Retry backoff agreed — 1 min, 5 min, then 15 min between attempts.'),
        ],
        notes: [
          NoteSection(heading: 'Decisions made', points: [
            'Local-first: every recording is saved on the phone before anything uploads.',
            'Sync queue retries with backoff — 1 min, 5 min, then 15 min.',
            'A failed upload stays visible in the queue; nothing is dropped silently.',
          ]),
          NoteSection(heading: 'Open questions', points: [
            'How large can the offline queue grow before the phone warns the user?',
            'Should sync prefer Wi-Fi only, or also use mobile data for small files?',
          ]),
        ],
        actions: [
          'Rahim to confirm the queue size limit with the team by Thursday.',
          'Draft the Wi-Fi-only vs mobile-data setting for the next meeting.',
        ],
        summaryReady: true,
      ),
      Session(
        id: 'cis313-minimax',
        title: 'CIS313 — Minimax & Alpha-Beta Pruning',
        subject: 'CIS313',
        category: 'Class',
        date: '2026-11-23',
        time: '10:30',
        duration: '1h 35m',
        durationMin: 95,
        filename: '2026-11-23_10-30_CIS313_Minimax.md',
        language: 'Banglish',
        tokens: 980,
        summary:
            'Sir taught minimax for two-player games, then alpha-beta pruning: how the alpha and beta bounds cut branches that can never change the result, and why move ordering decides how much pruning you actually get. The class traced a small game tree on the board and counted the nodes pruned.',
        examHints: [
          ExamHint(
              time: '00:21:45',
              text:
                  "Sir said 'exam-e asbe' — trace alpha-beta on a given tree and count pruned nodes."),
          ExamHint(
              time: '00:55:30',
              text:
                  'Best case pruning happens with perfect move ordering — remember the O(b^(d/2)) result.'),
        ],
        notes: [
          NoteSection(heading: 'Minimax', points: [
            'MAX tries to maximise the score, MIN tries to minimise it, alternating levels.',
            'The value of a node is the best value its player can force from that position.',
          ]),
          NoteSection(heading: 'Alpha-beta pruning', points: [
            'Alpha is the best value MAX can guarantee so far; beta is the best value MIN can guarantee.',
            'When beta ≤ alpha, the branch is cut — it cannot change the result.',
            'Sir bollo, ordering bhalo hole pruned node onek beshi hoy.',
          ]),
        ],
        actions: [
          'Trace the board game tree again and mark every pruned branch.',
          'Memorise the best-case and worst-case node counts for alpha-beta.',
        ],
        summaryReady: true,
      ),
    ];
