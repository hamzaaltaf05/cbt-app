import 'package:cbt_app/models/facility_issue.dart';

class FacilityIssuesState {
  final List<FacilityIssue> issues;
  final Map<String, String> reporterNames;
  final IssueStatus? filterStatus;
  final bool isLoading;
  final String? errorMessage;

  const FacilityIssuesState({
    this.issues = const [],
    this.reporterNames = const {},
    this.filterStatus,
    this.isLoading = false,
    this.errorMessage,
  });

  List<FacilityIssue> get filteredIssues {
    if (filterStatus == null) return issues;
    return issues.where((issue) => issue.status == filterStatus).toList();
  }

  FacilityIssuesState copyWith({
    List<FacilityIssue>? issues,
    Map<String, String>? reporterNames,
    IssueStatus? filterStatus,
    bool clearFilter = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FacilityIssuesState(
      issues: issues ?? this.issues,
      reporterNames: reporterNames ?? this.reporterNames,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
