import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from qc_issue import set_status

def test_set_status_writes_registry(tmp_path):
    p = tmp_path / "reg.yaml"
    set_status("M04/a10/r", "wontfix", notes="old round", path=str(p))
    import yaml
    reg = yaml.safe_load(open(p))
    assert reg["M04/a10/r"]["status"] == "wontfix"
    assert reg["M04/a10/r"]["notes"] == "old round"

def test_set_status_rejects_bad_state(tmp_path):
    p = tmp_path / "reg.yaml"
    import pytest
    with pytest.raises(ValueError):
        set_status("M04/a10/r", "banana", path=str(p))
