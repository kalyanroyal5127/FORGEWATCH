"""Deterministic-capable software sensor simulator for virtual machines."""

from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


CONDITIONS = ("Normal", "Abnormal Vibration", "Overheating", "Overcurrent")


@dataclass
class Machine:
    machine_id: str
    name: str
    condition: str = "Normal"
    injected_condition: str | None = None
    degradation_pct: float = 0.0


class SensorSimulator:
    """Generate plausible readings; readings are simulated, not hardware data."""

    def __init__(self, machines: int = 4, seed: int | None = None,
                 fault_probability: float = 0.18) -> None:
        if machines < 1:
            raise ValueError("machines must be at least 1")
        if not 0 <= fault_probability <= 1:
            raise ValueError("fault_probability must be between 0 and 1")
        self.rng = random.Random(seed)
        self.fault_probability = fault_probability
        self.machines = [Machine(f"M-{i:03d}", f"Virtual Machine {i}")
                         for i in range(1, machines + 1)]

    def reading(self, machine: Machine) -> dict[str, Any]:
        machine.degradation_pct=min(100.0,machine.degradation_pct+self.rng.uniform(0.005,0.035))
        if machine.injected_condition:
            machine.condition = machine.injected_condition
        elif self.rng.random() < self.fault_probability:
            machine.condition = self.rng.choice(CONDITIONS[1:])
        else:
            machine.condition = "Normal"

        vibration = self.rng.gauss(2.2, 0.45)
        temperature = self.rng.gauss(58, 4)
        current = self.rng.gauss(8.5, 1.0)
        wear=machine.degradation_pct/100.0
        vibration += wear*1.6
        temperature += wear*12.0
        current += wear*1.8
        if machine.condition == "Abnormal Vibration":
            vibration = self.rng.gauss(7.2, 0.8)
        elif machine.condition == "Overheating":
            temperature = self.rng.gauss(94, 5)
        elif machine.condition == "Overcurrent":
            current = self.rng.gauss(16, 1.6)

        return {
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "machine_id": machine.machine_id,
            "machine_name": machine.name,
            "vibration": round(max(0.0, vibration), 3),
            "temperature": round(max(0.0, temperature), 2),
            "current": round(max(0.0, current), 3),
            "condition": machine.condition,
            "degradation_pct": round(machine.degradation_pct,3),
        }

    def sample(self) -> list[dict[str, Any]]:
        return [self.reading(machine) for machine in self.machines]

    def inject_fault(self, machine_id: str, condition: str) -> None:
        machine=next((m for m in self.machines if m.machine_id==machine_id),None)
        if not machine: raise ValueError('Unknown machine')
        if condition not in CONDITIONS[1:]: raise ValueError('Unsupported injected fault condition')
        machine.injected_condition=condition
        machine.condition=condition

    def clear_faults(self) -> None:
        for machine in self.machines:
            machine.injected_condition=None
            machine.condition='Normal'


if __name__ == "__main__":
    import json
    print(json.dumps(SensorSimulator(seed=7).sample(), indent=2))
