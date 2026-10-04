// Stage manager for the stream demo: only active when the kit's demo player is loaded (its sigf_waves CVar
// exists). Console waits in demo.cfg all run out before the map starts, so the timed moments live here:
// hire vagrants, a Greed raid, a TNT shove, the crown theft, then the Blood Moon march on the west portal.

class BlockshireDirector : EventHandler
{
	bool active;
	int step;
	Array<int> done;   // staged moments already played (seconds), retried each second until they work

	override void WorldLoaded(WorldEvent e)
	{
		active = CVar.FindCVar("sigf_waves") != null && level.MapName ~== "MAP01";
	}

	PlayerPawn Monarch() { return players[consoleplayer].mo; }

	// Spawns cls about dist ahead of the Monarch (side = degrees off the view), on the floor, in sight.
	Actor Ahead(Class<Actor> cls, double dist, double side = 0, bool puff = true)
	{
		let p = Monarch();
		if (!p) return null;
		for (int k = 0; k < 24; k++)
		{
			double a = p.angle + side + (k < 10 ? (k ? frandom(-35, 35) : 0) : frandom(-180, 180));
			double d = dist * (k ? frandom(0.7, 1.15) : 1);
			Vector2 xy = p.Vec2Angle(d, a);
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - p.pos.z) > 40) continue;
			let m = Actor.Spawn(cls, (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !p.CheckSight(m)) { m.Destroy(); continue; }
			m.angle = m.AngleTo(p);
			if (m.bIsMonster && !m.bFriendly) { m.target = p; if (m.SeeState) m.SetState(m.SeeState); }
			if (puff)
			{
				for (int i = 0; i < 8; i++)
				{
					let g = Actor.Spawn(m.bIsMonster && !m.bFriendly ? "GreedGoo" : "GoldSparkle", m.pos + (frandom(-12, 12), frandom(-12, 12), frandom(0, 40)));
					if (g) g.vel = (frandom(-2, 2), frandom(-2, 2), frandom(1, 3));
				}
			}
			return m;
		}
		return null;
	}

	GreedPortal WestPortal()
	{
		let k = BlockshireHandler.Get();
		if (!k) return null;
		GreedPortal best = null;
		for (int i = 0; i < k.portals.Size(); i++)
		{
			let gp = k.portals[i];
			if (gp && gp.health > 0 && (!best || gp.pos.x < best.pos.x)) best = gp;
		}
		return best;
	}

	// One staged moment; false = could not place it yet (try again next second).
	bool Stage(int at, PlayerPawn p)
	{
		switch (at)
		{
		case 0:
			p.A_SelectWeapon("CoinFlick");
			return true;
		case 1:     // two vagrants by the road: the purse hires them on sight
		{
			let a = Ahead("Vagrant", 190, -14);
			let b = Ahead("Vagrant", 225, 14);
			return a || b;
		}
		case 3:     // the first Greed raid
		{
			let a = Ahead("Greedling", 520, -10);
			let b = Ahead("Greedling", 600, 15);
			return a || b;
		}
		case 7:
		{
			let a = Ahead("Greedling", 480, 0);
			Ahead("TNTBlock", 420, 8, false);
			Ahead("Greedling", 520, 20);
			return a != null;
		}
		case 8:     // TNT time
			p.A_SelectWeapon("TNTSwat");
			return true;
		case 10:
			return Ahead("Greedling", 450, -15) || Ahead("Greedling", 470, 15);
		case 14:    // the Crown Stealer
			p.A_SelectWeapon("CoinFlick");
			return Ahead("GreedBrute", 120, 0) != null;
		case 19:
			Ahead("Vagrant", 210, 30);
			return Ahead("Greedling", 560, -20) != null;
		}
		return true;
	}

	override void WorldTick()
	{
		if (!active) return;
		let p = Monarch();
		if (!p) return;
		int s = level.maptime / 35;
		// Keep the purse and the TNT stocked: the show must go on.
		if (level.maptime % 35 == 0)
		{
			if (p.CountInv("Coins") < 12) p.GiveInventory("Coins", 12);
			if (p.CountInv("TNTAmmo") < 4) p.GiveInventory("TNTAmmo", 4);
		}
		if (level.maptime % 35) return;

		static const int AT[] = { 0, 1, 3, 7, 8, 10, 14, 19 };
		for (int i = 0; i < AT.Size(); i++)
		{
			if (s < AT[i] || done.Find(AT[i]) != done.Size()) continue;
			if (Stage(AT[i], p)) done.Push(AT[i]);
		}
		// Daytime: always someone to fight in front, so the Monarch faces the action, not a wall.
		if (s >= 4 && s < 24 && s % 2 == 0)
		{
			let k = BlockshireHandler.Get();
			if (k && !BlockshireHandler.NearestGreed(p, 1000)) Ahead("Greedling", 480, frandom(-20, 20));
		}
		// From the Blood Moon on (30 s): raids keep coming from the west, pulling the fight to the portal.
		if (s >= 40 && s % 4 == 0)
		{
			let west = WestPortal();
			double side = west ? Actor.deltaangle(p.angle, p.AngleTo(west)) : 0;
			if (abs(side) < 70) Ahead(random(0, 4) ? "Greedling" : "GreedBrute", 600, side + frandom(-20, 20));
		}
		// An open rift close by: TNT is the tool for the job.
		let rit = ThinkerIterator.Create("RiftPortal");
		Actor rift;
		while (rift = Actor(rit.Next()))
		{
			if (rift.health <= 0 || p.Distance2D(rift) > 900) continue;
			let w = p.player.ReadyWeapon;
			if (!w || !(w is "TNTSwat")) p.A_SelectWeapon("TNTSwat");
			break;
		}
		let wp = WestPortal();
		if (wp && s >= 45)
		{
			double d = p.Distance2D(wp);
			let w = p.player.ReadyWeapon;
			if (d < 800 && (!w || !(w is "TNTSwat"))) p.A_SelectWeapon("TNTSwat");
		}
	}
}
