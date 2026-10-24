# BaizeBook 1.0.1 (7) — What to Test

Free balls, clearer score differences, frame resets and drawn sessions.

1. Record a foul and choose Free ball. All eligible colours should become selectable on the main scoring screen. With a red on, potting a nominated black adds one point without removing a red; the next colour scores normally. Undo and redo should restore the free-ball choices. During the colour clearance, cleared colours stay disabled and a nominated free ball scores the ball-on value, leaving the actual ball on available. The Free ball sheet still supports potting both balls in one shot.
2. Check each player's score card. A small bold difference appears below the score, such as **(-17)** and **(+17)**. It disappears at equal scores and updates after scoring, fouls, undo and redo. Check readability with the phone on the table.
3. Open the match menu and choose Reset frame. Cancel must preserve play. Confirming restarts only this frame at 0–0 with the original reds and break-off player, including when paused. Earlier frame wins remain. Undo restores the previous scores, balls, break and timer; redo reapplies the reset. Relaunch and check persistence.
4. In either a best-of match or an open session, choose End session. If completed frame wins are equal, the action reads End session as a draw. Finish at 0–0, after equal completed frames, and with equal scores partway through a frame. The result and History should say Draw, without requiring a winner. Unfinished scores stay in history and do not award a frame. Unequal completed frame wins still produce a winner. Head-to-head statistics list draws separately from losses.
5. Undo and redo ending a session. Closing an already paused frame or a completed frame must preserve its scores and result when reopened. Check existing players and history after updating and round-trip a backup.
6. With the Watch connected, check free-ball colour choices and ball-on values. A stale tap sent before a frame reset must be rejected; a drawn session should say Match drawn.

Both phone and embedded Watch use version 1.0.1, build 7. Physical device testing remains with the account holder. All records stay on the device.
