class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votes;
  final int totalVotes;
  final DateTime endDate;
  final String? userVotedOption; // La opción seleccionada por el usuario si ya votó

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.totalVotes,
    required this.endDate,
    this.userVotedOption,
  });

  Poll copyWith({
    String? id,
    String? question,
    List<String>? options,
    Map<String, int>? votes,
    int? totalVotes,
    DateTime? endDate,
    String? userVotedOption,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      totalVotes: totalVotes ?? this.totalVotes,
      endDate: endDate ?? this.endDate,
      userVotedOption: userVotedOption ?? this.userVotedOption,
    );
  }
}
