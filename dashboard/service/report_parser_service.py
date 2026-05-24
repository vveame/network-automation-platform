class ReportParserService:
    CRITICAL_PATTERNS = [
        "fatal:",
        "UNREACHABLE!",
        "FAILED!",
        "Traceback",
        "ERROR!",
    ]

    def detect_status(self, content: str) -> str:
        if not content or not content.strip():
            return "missing"

        for pattern in self.CRITICAL_PATTERNS:
            if pattern in content:
                return "failed"

        return "passed"

    def detect_category(self, filename: str) -> str:
        name = filename.lower()

        if "summary" in name:
            return "Summary"

        if "oob" in name or "readiness" in name:
            return "OOB Management"

        if name.endswith("-ovs.txt"):
            return "OVS Validation"

        if name.endswith("-frr.txt"):
            return "FRR Validation"

        if "dmz" in name:
            return "DMZ Services"

        if "security" in name:
            return "Security"

        if "end-to-end" in name or "end_to_end" in name:
            return "End-to-End"

        return "Other Reports"

    def title_from_filename(self, filename: str) -> str:
        title = filename.replace(".txt", "")
        title = title.replace("_", " ")
        title = title.replace("-", " ")
        return title.title()

    def extract_summary(self, content: str) -> str:
        if not content or not content.strip():
            return "No content available."

        lines = [line.strip() for line in content.splitlines() if line.strip()]
        useful_lines = []

        keywords = [
            "===",
            "host:",
            "target:",
            "project:",
            "environment:",
            "control plane:",
            "validation",
            "oob",
            "dmz",
            "web",
            "dns",
            "ospf",
            "vrrp",
            "security",
            "reachable",
            "succeeded",
            "passed",
            "failed",
        ]

        for line in lines:
            lower = line.lower()
            if any(keyword in lower for keyword in keywords):
                useful_lines.append(line)

        if useful_lines:
            return " | ".join(useful_lines[:4])

        return " | ".join(lines[:3])
