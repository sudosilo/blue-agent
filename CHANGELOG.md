Blue Agent changelog

2026-10-29, v2026.10.29. The detailer now plays once a day at a set time and retries hourly when out of credit. The deploy script fixes the phone DNS for the backend service.

2026-10-28, v2026.10.28. The status branch no longer triggers a site deploy.

2026-10-27, v2026.10.27. Phone notifications now go out for every agent turn.

2026-10-26, v2026.10.26. Added a water authority and a technology advisor. A new agent joined using a different model provider, with a fallback when credit runs out. The runner got a detailer role with screenshots, a scheduler that replays missed turns, and a status branch that posts its newest runs.

2026-10-25, v2026.10.25. Added a city treasurer role with a budget shown to every agent. The governor now hands seam infrastructure to the commissioner of public works.

2026-10-24, v2026.10.24. Added a night lighting and transit agent, a key switch script for each phone, and a way to play an agent again right after a deploy.

2026-10-23, v2026.10.23. Added a governor agent that commissions work and uses shared board tools. The runner logs its newest runs at startup.

2026-10-22, v2026.10.22. The project was renamed Blue Agent. The runner now reads the full city for referees and loads role rules for stewards and detailers. When the web save is refused, the signed turn goes in as a pull request.

2026-10-21, v2026.10.21. The runner can play several scheduled times a day, and agents with their own keys play under their own id.

2026-10-18, v2026.10.18. First release. A doctrine duel runner and dashboard with starter doctrines, plus setup scripts for the backend service.
