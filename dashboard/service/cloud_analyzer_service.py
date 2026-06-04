from dto.cloud_analyzer_dto import CloudAnalyzerDTO


class CloudAnalyzerService:
    def __init__(self, cloud_analyzer_repository):
        self.cloud_analyzer_repository = cloud_analyzer_repository

    def get_latest_decision(self) -> CloudAnalyzerDTO:
        data = self.cloud_analyzer_repository.load_latest_decision()

        if not data:
            return CloudAnalyzerDTO(
                available=False,
                anomaly_status="unavailable",
                risk_score=0,
                severity="unknown",
                recommended_action="sync_dashboard_cache_from_s3",
                build_label="N/A",
                failed_reports=[],
                warning_reports=[],
                source_file="/var/lib/pfe-dashboard/analyzer/latest/decision.json",
            )

        return CloudAnalyzerDTO(
            available=True,
            anomaly_status=data.get("anomaly_status", "unknown"),
            risk_score=int(data.get("risk_score", 0)),
            severity=data.get("severity", "unknown"),
            recommended_action=data.get("recommended_action", "unknown"),
            build_label=data.get("build_label", "unknown"),
            failed_reports=data.get("failed_reports", []),
            warning_reports=data.get("warning_reports", []),
            source_file="/var/lib/pfe-dashboard/analyzer/latest/decision.json",
        )
