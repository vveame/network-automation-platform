import csv
import json
from pathlib import Path
from typing import Any, Dict, Optional


class RuntimeArtifactService:
    """
    Reads runtime artifacts synchronized from S3 into /var/lib/pfe-dashboard.

    This service exposes:
    - final hybrid decision
    - ML Isolation Forest decision
    - remediation plan/apply outputs
    """

    def __init__(
        self,
        final_decision_file: Path,
        final_report_file: Path,
        ml_decision_file: Path,
        ml_scores_file: Path,
        ml_dataset_file: Path,
        remediation_dir: Path,
    ):
        self.final_decision_file = Path(final_decision_file)
        self.final_report_file = Path(final_report_file)
        self.ml_decision_file = Path(ml_decision_file)
        self.ml_scores_file = Path(ml_scores_file)
        self.ml_dataset_file = Path(ml_dataset_file)
        self.remediation_dir = Path(remediation_dir)

    def get_final_decision(self) -> Dict[str, Any]:
        data = self._read_json(self.final_decision_file)

        if not data:
            return self._unavailable(
                artifact="final_decision",
                source_file=self.final_decision_file,
                message="No final hybrid decision found.",
            )

        merged = data.get("merged_decision", {})

        return {
            "available": True,
            "classification": merged.get("classification", "unknown"),
            "final_status": merged.get("final_status", "unknown"),
            "final_severity": merged.get("final_severity", "unknown"),
            "final_risk_score": self._safe_int(merged.get("final_risk_score", 0)),
            "confidence": merged.get("confidence", "unknown"),
            "recommended_action": merged.get("recommended_action", "unknown"),
            "remediation_allowed": bool(merged.get("remediation_allowed", False)),
            "remediation_mode": merged.get("remediation_mode", "unknown"),
            "decision_reason": merged.get("decision_reason", ""),
            "rule_anomalous": bool(merged.get("rule_anomalous", False)),
            "ml_anomalous": bool(merged.get("ml_anomalous", False)),
            "ml_suspicious": bool(merged.get("ml_suspicious", False)),
            "generated_at_utc": data.get("generated_at_utc", "unknown"),
            "engine": data.get("engine", "unknown"),
            "source_file": str(self.final_decision_file),
            "report_available": self.final_report_file.exists(),
            "report_file": str(self.final_report_file),
            "raw": data,
        }

    def get_ml_decision(self) -> Dict[str, Any]:
        data = self._read_json(self.ml_decision_file)

        if not data:
            return self._unavailable(
                artifact="ml_decision",
                source_file=self.ml_decision_file,
                message="No ML decision found.",
            )

        scores_rows = self._count_csv_rows(self.ml_scores_file)
        dataset_rows = self._count_csv_rows(self.ml_dataset_file)

        top_features = data.get("top_unusual_features", [])
        if not isinstance(top_features, list):
            top_features = []

        return {
            "available": True,
            "engine": data.get("engine", "ml_isolation_forest"),
            "model_type": data.get("model_type", "IsolationForest"),
            "ml_status": data.get("ml_status", "unknown"),
            "severity": data.get("severity", "unknown"),
            "ml_risk_score": self._safe_int(data.get("ml_risk_score", 0)),
            "latest_prediction": data.get("latest_prediction", "unknown"),
            "latest_decision_score": data.get("latest_decision_score"),
            "latest_sample_score": data.get("latest_sample_score"),
            "latest_timestamp": data.get("latest_timestamp", "unknown"),
            "outlier_rows": self._safe_int(data.get("outlier_rows", 0)),
            "scored_rows": self._safe_int(data.get("scored_rows", 0)),
            "outlier_ratio": data.get("outlier_ratio", 0),
            "recommended_action": data.get("recommended_action", "unknown"),
            "analysis_time_utc": data.get("analysis_time_utc", "unknown"),
            "top_unusual_features": top_features,
            "scores_file_available": self.ml_scores_file.exists(),
            "scores_rows": scores_rows,
            "dataset_file_available": self.ml_dataset_file.exists(),
            "dataset_rows": dataset_rows,
            "source_file": str(self.ml_decision_file),
            "scores_file": str(self.ml_scores_file),
            "dataset_file": str(self.ml_dataset_file),
            "raw": data,
        }

    def get_remediation(self) -> Dict[str, Any]:
        plan = self._load_remediation_mode("plan")
        apply = self._load_remediation_mode("apply")

        latest = apply if apply.get("available") else plan

        return {
            "available": bool(plan.get("available") or apply.get("available")),
            "latest": latest,
            "plan": plan,
            "apply": apply,
            "source_dir": str(self.remediation_dir),
        }

    def _load_remediation_mode(self, mode: str) -> Dict[str, Any]:
        mode_dir = self.remediation_dir / mode
        plan_file = mode_dir / "remediation-plan.json"
        report_file = mode_dir / "remediation-report.txt"

        data = self._read_json(plan_file)
        report_preview = self._read_text_preview(report_file)

        if not data and not report_preview:
            return {
                "available": False,
                "mode": mode,
                "selected_action": "unavailable",
                "executed": False,
                "success": False,
                "source_file": str(plan_file),
                "report_file": str(report_file),
                "report_preview": "",
            }

        result = data.get("result", {}) if data else {}
        decision_context = data.get("decision_context", {}) if data else {}

        return {
            "available": True,
            "mode": mode,
            "selected_action": data.get(
                "selected_action",
                result.get("action", "unknown"),
            ) if data else "unknown",
            "requested_action": data.get("requested_action", "unknown") if data else "unknown",
            "action_type": data.get("action_type", "unknown") if data else "unknown",
            "modifies_infrastructure": bool(data.get("modifies_infrastructure", False)) if data else False,
            "executed": bool(result.get("executed", False)),
            "success": bool(result.get("success", False)),
            "exit_codes": result.get("exit_codes", []),
            "classification": decision_context.get("classification", "unknown"),
            "final_status": decision_context.get("final_status", "unknown"),
            "final_risk_score": self._safe_int(decision_context.get("final_risk_score", 0)),
            "remediation_allowed": bool(decision_context.get("remediation_allowed", False)),
            "generated_at_utc": data.get("generated_at_utc", "unknown") if data else "unknown",
            "source_file": str(plan_file),
            "report_file": str(report_file),
            "report_preview": report_preview,
            "raw": data or {},
        }

    def _read_json(self, path: Path) -> Optional[Dict[str, Any]]:
        if not path.exists() or not path.is_file():
            return None

        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None

    def _read_text_preview(self, path: Path, max_chars: int = 4000) -> str:
        if not path.exists() or not path.is_file():
            return ""

        try:
            return path.read_text(encoding="utf-8", errors="replace")[:max_chars]
        except OSError:
            return ""

    def _count_csv_rows(self, path: Path) -> int:
        if not path.exists() or not path.is_file():
            return 0

        try:
            with path.open("r", encoding="utf-8", errors="replace") as f:
                reader = csv.reader(f)
                rows = list(reader)
            return max(len(rows) - 1, 0)
        except OSError:
            return 0

    def _safe_int(self, value: Any, default: int = 0) -> int:
        try:
            return int(round(float(value)))
        except (TypeError, ValueError):
            return default

    def _unavailable(
        self,
        artifact: str,
        source_file: Path,
        message: str,
    ) -> Dict[str, Any]:
        return {
            "available": False,
            "artifact": artifact,
            "message": message,
            "source_file": str(source_file),
        }
