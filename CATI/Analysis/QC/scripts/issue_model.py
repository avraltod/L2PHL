"""Data model for the issue-intelligence core."""
import re
from dataclasses import dataclass, field
from typing import Optional

VERDICTS = ("A1", "A2", "B", "C", "D", "REVIEW")
OWNER = {
    "A1": "firm-questionnaire",   # Kobo skip logic wrong/missing
    "A2": "firm-field",           # gate correct but response violates it
    "B":  "firm-dofile",          # recode/pooler processing
    "C":  "us",                   # our QC check / representation bug
    "D":  "expected",             # structural / not a real issue
    "REVIEW": "unassigned",
}
OPEN_STATES   = {"new", "acknowledged", "fix-pending", "reopened"}
CLOSED_STATES = {"resolved", "wontfix", "accepted"}

def slugify(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)[:60]

def issue_key(module: str, variable: str, rule_id: str) -> str:
    return f"{module}/{variable}/{rule_id}"

@dataclass
class Flag:
    module: str
    variable: str
    rule_id: str
    kind: str                       # "skip" | "mandatory" | "oor"
    counts_by_round: dict           # {"1": int, ..., "8": int}
    severity: str = "medium"
    label: str = ""
    @property
    def key(self) -> str:
        return issue_key(self.module, self.variable, self.rule_id)
    @property
    def total(self) -> int:
        return sum(int(v) for v in self.counts_by_round.values() if isinstance(v, (int, float)) and v)

@dataclass
class Evidence:
    data: dict = field(default_factory=dict)
    kobo: dict = field(default_factory=dict)
    dofile: dict = field(default_factory=dict)
    notes: list = field(default_factory=list)

@dataclass
class Issue:
    key: str
    flag: Flag
    evidence: Evidence
    proposed_verdict: str
    confidence: str
    rule_fired: str
    verdict: Optional[str] = None       # confirmed (registry); falls back to proposed
    owner: Optional[str] = None
    status: str = "new"
    report_to_firm: bool = False
    rounds: dict = field(default_factory=dict)
    registry_notes: str = ""
    @property
    def effective_verdict(self) -> str:
        return self.verdict or self.proposed_verdict
