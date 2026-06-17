# Mechanic: Off-Road Respawn

**Input:** None. The race scene monitors the player car automatically.

**Response:** While the car is inside the road width, the race scene records the nearest track distance. If the car stays outside the road margin for a short grace period, or falls below the road surface, it respawns centered on the last valid road distance and faces forward along the track.

**Feedback:**
- Visual: immediate reposition onto the road center. Future polish should add a short fade or ghost effect.
- Audio: none yet. Future polish should add a quick recovery sting.
- Mechanical: velocity resets to zero so the car does not carry bad launch/off-road momentum into the respawn.

**Failure modes:**
- Brief curb/edge drift: tolerated by `road_touch_tolerance_m` and `offroad_respawn_delay_s`.
- Leaving the road entirely: respawn after `offroad_respawn_delay_s`.
- Falling below the track: immediate respawn once below `fall_respawn_depth_m`.
- Track query unavailable: safety system does nothing rather than crashing.

**Tunables:** `track_safety_enabled`, `road_touch_tolerance_m`, `offroad_respawn_margin_m`, `offroad_respawn_delay_s`, `fall_respawn_depth_m`, `respawn_vertical_offset_m`.

**Depth:** This is a safety mechanic, not a skill expression mechanic. It protects playtesting and prevents unfinished terrain/barrier work from ending a run.
