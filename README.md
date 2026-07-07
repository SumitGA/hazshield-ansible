# HazShield — Phase 1 state node + stub API (Ansible)

Configures hazshield-state (PostgreSQL 16 + TimescaleDB + Redis) and
deploys a stub FastAPI on hazshield-edge so api.<domain>/health returns
the first end-to-end 200.

## Before running

1. Edit `inventory.ini`: replace <EDGE_FLOATING_IP> (2 places).
2. Edit `group_vars/all.yml`: set real pg_password / redis_password.
3. Install Ansible + the postgres collection on your control machine:

       pip install ansible
       ansible-galaxy collection install community.postgresql

## Run

    ansible-playbook site.yml

Idempotent — rerun freely after any change.

## Checkpoints

- [ ] `ansible-playbook site.yml` completes with no failed tasks
- [ ] From edge VM:  psql "postgresql://hazshield:<pw>@10.10.0.12/hazshield" -c '\dt'
      shows site/zone/asset/sensor/alarm_events/isolation_plans
- [ ] `SELECT * FROM timescaledb_information.jobs;` lists compression,
      retention, and 2 continuous-aggregate policies
- [ ] From edge VM:  redis-cli -h 10.10.0.12 -a <pw> ping  -> PONG
- [ ] From your PHONE on LTE: https://api.<yourdomain>/health -> JSON 200
- [ ] Negative test from compute VM: redis works, but SSH to state
      directly from your LAN fails (bastion-only, secgroups enforcing)

## Design notes (interview material)

- postgresql.conf untouched; all tuning in conf.d/hazshield.conf —
  survives package upgrades, diffs cleanly.
- synchronous_commit=off globally: bulk telemetry tolerates <1s loss on
  crash. Safety-critical writes (alarm_events) will SET LOCAL
  synchronous_commit=on per-transaction in Phase 3.
- Redis noeviction + AOF: the hot lane fails loudly instead of silently
  dropping violations; producers spill locally when Redis pushes back.
- pg_hba + secgroups are two independent layers enforcing the same
  policy (defense in depth).
