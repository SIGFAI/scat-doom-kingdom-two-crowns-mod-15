// Kingdom's people and places: vagrants who work for one coin, archers who escort the Monarch,
// the Greed portals (Nether portals here) and the camp props.

class Vagrant : Actor
{
	bool hired, caught;

	Default
	{
		Radius 14;
		Height 54;
		Speed 3;
		Scale 0.5;
		Mass 100;
		+SOLID
		+NOTARGET
		+FLOORCLIP
		MaxStepHeight 24;
		Tag "Vagrant";
	}

	// The Monarch walked by with coins: one is tossed over, the vagrant waits for it.
	void Hire(Actor monarch)
	{
		hired = true;
		angle = AngleTo(monarch);
		TossedCoin.Throw(monarch, self, 18);
		SetStateLabel("Waiting");
	}

	void CatchCoin()
	{
		caught = true;
		A_StartSound("coin/pick", CHAN_ITEM);
		SetStateLabel("Hired");
	}

	void A_BecomeArcher()
	{
		let a = Archer(Spawn("Archer", pos, ALLOW_REPLACE));
		if (a) { a.angle = angle; a.A_StartSound("kingdom/recruit", CHAN_VOICE); }
		for (int i = 0; i < 34; i++)
		{
			let s = Spawn("GoldSparkle", pos + (frandom(-16, 16), frandom(-16, 16), frandom(0, 60)));
			if (s) { s.vel = (frandom(-1.5, 1.5), frandom(-1.5, 1.5), frandom(0.5, 3.5)); s.scale *= 1.6; }
		}
		let f = Spawn("CoinFlash", pos + (0, 0, 30));
		if (f) f.scale *= 2.5;
		let k = BlockshireHandler.Get();
		if (k) k.Hired(a);
		Destroy();
	}

	States
	{
	Spawn:
		VAGR E 20;
		VAGR AABBCCDD 4 A_Wander;
		VAGR E 30;
		VAGR AABBCCDD 4 A_Wander;
		VAGR AABBCCDD 4 A_Wander;
		Loop;
	Waiting:
		VAGR E 1;
		Wait;
	Hired:
		VAGR F 5;
		VAGR G 5;
		VAGR F 5;
		VAGR G 5;
		VAGR H 6;
		TNT1 A 0 A_BecomeArcher;
		Stop;
	}
}

class Archer : Actor
{
	Default
	{
		Monster;
		+FRIENDLY
		+FLOORCLIP
		+NOTARGETSWITCH
		-COUNTKILL
		Health 170;
		Radius 14;
		Height 54;
		Speed 10;
		Mass 120;
		Scale 0.5;
		PainChance 90;
		MinMissileChance 60;
		MaxTargetRange 1500;
		PainSound "greed/attack";
		DeathSound "coin/spill";
		Tag "Archer";
		Obituary "%o was shot by a loyal archer.";
	}

	// The Monarch's own blasts and paws never hurt the hired help.
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (source && (source.player || source.bFriendly)) return 0;
		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	// Fight the nearest Greed in sight, else walk with the Monarch.
	void A_ArcherThink()
	{
		if (target && (target.health <= 0 || target.player || target.bFriendly)) target = null;
		if (!target || level.maptime % 35 == 0)
		{
			let g = BlockshireHandler.NearestGreed(self, 1300);
			if (g) target = g;
			// no Greed in sight: the army marches on an open rift
			if (!target)
			{
				let it = ThinkerIterator.Create("RiftPortal");
				Actor r;
				while (r = Actor(it.Next()))
					if (r.health > 0 && Distance2D(r) < 1400 && CheckSight(r)) { target = r; break; }
			}
			// the crown thief comes first
			let k = BlockshireHandler.Get();
			if (k && k.thief && k.thief.health > 0 && Distance2D(k.thief) < 1300 && CheckSight(k.thief)) target = k.thief;
		}
		if (target) { A_Chase(); return; }
		let p = players[consoleplayer].mo;
		if (!p) return;
		double d = Distance2D(p);
		if (d > 180)
		{
			angle = AngleTo(p);
			Vector2 step = Actor.AngleToVector(angle, speed);
			if (!TryMove(pos.xy + step, 0)) angle += frandom(-60, 60);
		}
		else if (d < 150)
		{
			// give the Monarch room: step aside rather than crowd the view
			angle = p.AngleTo(self) + frandom(-30, 30);
			TryMove(pos.xy + Actor.AngleToVector(angle, speed * 0.6), 0);
		}
		else if (random(0, 20) == 0) angle += frandom(-45, 45);
	}

	void A_Loose()
	{
		if (!target) return;
		A_FaceTarget();
		A_StartSound("bow/shot", CHAN_WEAPON);
		A_SpawnProjectile("ArcherArrow", 38, 4, frandom(-2, 2));
	}

	void A_FallAndQuit()
	{
		// Kingdom: a fallen archer drops the bow and is a vagrant again.
		let v = Spawn("Vagrant", pos, ALLOW_REPLACE);
		if (v) v.angle = angle;
		let k = BlockshireHandler.Get();
		if (k) k.Notice("An archer fell and dropped the bow. Hire them again!");
	}

	States
	{
	Spawn:
		ARCH A 4 A_ArcherThink;
		Loop;
	See:
		ARCH AABBCCDD 2 A_ArcherThink;
		Loop;
	Missile:
		ARCH E 9 A_FaceTarget;
		ARCH E 3 A_Loose;
		ARCH F 7;
		ARCH E 4;
		Goto See;
	Pain:
		ARCH G 6 A_Pain;
		Goto See;
	Death:
		ARCH G 4 A_Scream;
		ARCH H 5 A_NoBlocking;
		ARCH I 40;
		TNT1 A 0 A_FallAndQuit;
		Stop;
	}
}

class ArcherArrow : Actor
{
	Default
	{
		Projectile;
		Radius 4;
		Height 6;
		Speed 30;
		Scale 0.8;
		DamageFunction (7 + random(0, 6));
		SeeSound "";
		DeathSound "bow/hit";
		+THRUGHOST
	}
	States
	{
	Spawn:
		ARRW A -1;
		Stop;
	Death:
		ARRW A 20;
		ARRW A 1 A_FadeOut(0.1);
		Wait;
	XDeath:
		TNT1 A 1;
		Stop;
	}
}

// A Greed portal: an obsidian Nether portal in the cliffs. It breeds Greed (a flood at night),
// the Monarch's coins, paws and TNT break it.
class GreedPortal : Actor
{
	int lineTag;
	int nextSpawn;
	bool broken;

	Default
	{
		Health 600;
		Radius 64;
		Height 160;
		Mass 100000;
		+SHOOTABLE
		+SOLID
		+NOGRAVITY
		+DONTTHRUST
		+NOBLOOD
		+ISMONSTER
		+COUNTKILL
		+NOICEDEATH
		+DONTMORPH
		+NOTARGET
		+NOINFIGHTING
		PainChance 0;
		DeathSound "portal/break";
		Tag "Greed Portal";
	}

	override void BeginPlay()
	{
		Super.BeginPlay();
		nextSpawn = 35 * 4;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		lineTag = tid + 10;
		A_StartSound("portal/hum", CHAN_BODY, CHANF_LOOPING, 0.6, ATTN_STATIC);
		A_AttachLight("portalglow", DynamicLight.PointLight, Color(200, 40, 255), 220, 220, 0, (0, 0, 80));
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int r = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		Vector3 at = inflictor ? inflictor.pos : pos + (0, 0, 80);
		for (int i = 0; i < 4; i++)
		{
			let g = Spawn("GreedGoo", at + (frandom(-6, 6), frandom(-6, 6), frandom(-6, 6)));
			if (g) g.vel = (frandom(-3, 3), frandom(-3, 3), frandom(-1, 3));
		}
		SetLineAlpha(1.0);
		return r;
	}

	void SetLineAlpha(double a)
	{
		let it = level.CreateLineIDIterator(lineTag);
		int i;
		while ((i = it.Next()) >= 0) level.lines[i].alpha = a;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || broken) return;
		// pulse back to the resting glow after a hit
		if (level.maptime % 3 == 0)
		{
			let it = level.CreateLineIDIterator(lineTag);
			int i;
			while ((i = it.Next()) >= 0) level.lines[i].alpha = max(0.7, level.lines[i].alpha - 0.05);
		}
		if (health <= 0) return;
		let k = BlockshireHandler.Get();
		if (!k || --nextSpawn > 0) return;
		bool night = k.IsNight();
		nextSpawn = night ? random(55, 85) : random(35 * 9, 35 * 14);
		if (k.GreedCount() >= (night ? 16 : 6)) return;
		let p = players[consoleplayer].mo;
		if (!night && p && Distance2D(p) > 2600) return;
		SpawnGreed(night && random(0, 4) == 0 ? "GreedBrute" : "Greedling");
	}

	Actor SpawnGreed(Class<Actor> cls)
	{
		Vector2 xy = Vec2Angle(84, angle + frandom(-25, 25));
		let g = Spawn(cls, (xy, floorz));
		if (!g) return null;
		if (!g.TestMobjLocation()) { g.Destroy(); return null; }
		g.angle = angle;
		let p = players[consoleplayer].mo;
		if (p) { g.target = p; g.SetStateLabel("See"); }
		for (int i = 0; i < 6; i++)
		{
			let s = Spawn("GreedGoo", g.pos + (frandom(-10, 10), frandom(-10, 10), frandom(0, 40)));
			if (s) s.vel = (frandom(-2, 2), frandom(-2, 2), frandom(1, 3));
		}
		g.A_StartSound("greed/sight", CHAN_VOICE);
		return g;
	}

	void A_PortalCollapse()
	{
		broken = true;
		A_StopSound(CHAN_BODY);
		A_RemoveLight("portalglow");
		A_Scream();
		let it = level.CreateLineIDIterator(lineTag);
		int i;
		TextureID none;
		none.SetNull();
		while ((i = it.Next()) >= 0)
		{
			for (int s = 0; s < 2; s++) if (level.lines[i].sidedef[s]) level.lines[i].sidedef[s].SetTexture(Side.mid, none);
		}
		// The obsidian frame crumbles into the ground.
		Floor_LowerByValue(tid + 2, 6, 192);
		Floor_LowerByValue(tid + 4, 6, 192);
		Ceiling_LowerByValue(tid + 4, 6, 192);
		for (int n = 0; n < 24; n++)
		{
			let d = Spawn("ObsidianDebris", pos + (frandom(-20, 20), frandom(-64, 64), frandom(20, 170)));
			if (d) d.vel = (frandom(-6, 6), frandom(-6, 6), frandom(3, 10));
		}
		Blast.Boom(self, 0, 0, false);
		let k = BlockshireHandler.Get();
		if (k) k.PortalBroken(self);
	}

	void A_PortalBlast()
	{
		Blast.Boom(self, 60, 160, true);
		SetOrigin(pos, false);
	}

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	Death:
		TNT1 A 0 A_PortalCollapse;
		TNT1 A 12;
		TNT1 A 0 { SetOrigin(pos + (0, 0, 60), false); Blast.Boom(self, 80, 200, true); }
		TNT1 A 12;
		TNT1 A 0 { SetOrigin(pos + (0, 0, 40), false); Blast.Boom(self, 80, 200, true); }
		TNT1 A -1;
		Stop;
	}
}

// ---- camp and town props

class Campfire : Actor
{
	Default
	{
		Radius 20;
		Height 16;
		Scale 0.5;
		+SOLID
		Tag "Campfire";
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let f = Spawn("CampFlame", pos + (0, 0, 4));
		A_AttachLight("fire", DynamicLight.FlickerLight, Color(255, 150, 50), 150, 170, 0, (0, 0, 24), 0.4);
	}
	States
	{
	Spawn:
		CMPF A -1;
		Stop;
	}
}

class CampFlame : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 0.7;
	}
	States
	{
	Spawn:
		FIRE ABCDEFGH 3;
		Loop;
	}
}

class Tent : Actor
{
	Default
	{
		Radius 40;
		Height 56;
		Scale 0.5;
		+SOLID
	}
	States
	{
	Spawn:
		TENT A -1;
		Stop;
	}
}

class KingdomBanner : Actor
{
	Default
	{
		Radius 8;
		Height 80;
		Scale 0.6;
		+SOLID
	}
	States
	{
	Spawn:
		BANR A -1;
		Stop;
	}
}

class BlockTorch : Actor
{
	Default
	{
		Radius 6;
		Height 32;
		Scale 0.6;
		+SOLID
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight("torch", DynamicLight.FlickerLight, Color(255, 200, 100), 90, 100, 0, (0, 0, 36), 0.3);
	}
	States
	{
	Spawn:
		TRCH ABC 5 Bright;
		Loop;
	}
}

class WheatCrop : Actor
{
	Default
	{
		Radius 8;
		Height 24;
		Scale 0.5;
		+NOBLOCKMAP
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		frame = random(0, 1);
	}
	States
	{
	Spawn:
		WHET A -1;
		Stop;
	}
}

// The town's gold statue of the Monarch himself, on the throne dais.
class CatStatue : Actor
{
	Default
	{
		Radius 28;
		Height 72;
		Scale 1.4;
		+SOLID
		Translation "0:255=%[0.45,0.32,0.02]:[2.00,1.70,0.60]";
		Tag "Statue of Sir Whiskers";
	}
	States
	{
	Spawn:
		CATC E -1;
		Stop;
	}
}

// Farm animals and the court's cats: they wander, they have bodies, they keep the realm alive.
class Critter : Actor
{
	Default
	{
		Radius 10;
		Height 20;
		Speed 3;
		Scale 0.5;
		+SOLID
		+NOTARGET
		+FLOORCLIP
		MaxStepHeight 24;
	}
}

class Sheep : Critter
{
	Default { Radius 16; Height 30; }
	States
	{
	Spawn:
		SHEP A 20;
		SHEP ABABABAB 5 A_Wander;
		Loop;
	}
}

class Chick : Critter
{
	Default { Radius 8; Height 16; Speed 4; }
	States
	{
	Spawn:
		CHIK A 15;
		CHIK ABCDABCD 3 A_Wander;
		Loop;
	}
}

class Bunny : Critter
{
	Default { Radius 8; Height 18; Speed 5; }
	States
	{
	Spawn:
		BUNY A 25;
		BUNY ABCDABCD 3 A_Wander;
		Loop;
	}
}

class CourtCat : Critter
{
	Default { Radius 12; Height 30; Speed 4; Tag "Court cat"; }
	States
	{
	Spawn:
		CATK E 30;
		CATK ABCDABCD 3 A_Wander;
		CATK F 20;
		CATK ABCDABCD 3 A_Wander;
		Loop;
	}
}

// A Blood Moon rift: a free-standing Greed portal that tears open in the fields near the Monarch.
class RiftPortal : Actor
{
	int nextSpawn, grow;

	Default
	{
		Health 320;
		Radius 56;
		Height 180;
		Mass 100000;
		Scale 0.1;
		+SHOOTABLE
		+SOLID
		+DONTTHRUST
		+NOBLOOD
		+ISMONSTER
		+COUNTKILL
		+NOICEDEATH
		+NOTARGET
		+NOINFIGHTING
		+BRIGHT
		PainChance 0;
		DeathSound "portal/break";
		Tag "Blood Moon rift";
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		nextSpawn = 50;
		A_StartSound("portal/hum", CHAN_BODY, CHANF_LOOPING, 0.8, ATTN_NORM);
		A_StartSound("kingdom/horn", CHAN_VOICE, CHANF_DEFAULT, 0.8, ATTN_NONE);
		A_AttachLight("riftglow", DynamicLight.PointLight, Color(210, 50, 255), 260, 260, 0, (0, 0, 96));
		A_Quake(3, 20, 0, 1200, "");
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int r = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		Vector3 at = inflictor ? inflictor.pos : pos + (0, 0, 90);
		for (int i = 0; i < 5; i++)
		{
			let g = Spawn("GreedGoo", at + (frandom(-6, 6), frandom(-6, 6), frandom(-6, 6)));
			if (g) g.vel = (frandom(-3, 3), frandom(-3, 3), frandom(-1, 3));
		}
		if (health > 0 && random(0, 2) == 0)
		{
			let d = Spawn("ObsidianDebris", at);
			if (d) d.vel = (frandom(-4, 4), frandom(-4, 4), frandom(2, 6));
		}
		return r;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || health <= 0) return;
		if (grow < 24) { grow++; A_SetScale(0.1 + 0.9 * grow / 24.0); }
		if (--nextSpawn > 0) return;
		nextSpawn = random(70, 100);
		let k = BlockshireHandler.Get();
		let p = players[consoleplayer].mo;
		// up close the rift is busy holding itself together: no more Greed, just a target
		if (k && k.GreedCount() >= (p && Distance2D(p) < 600 ? 1 : 4)) return;
		Vector2 xy = Vec2Angle(radius + 30, p ? AngleTo(p) + frandom(-40, 40) : frandom(0, 360));
		let g = Spawn(random(0, 5) ? "Greedling" : "GreedBrute", (xy, floorz));
		if (!g) return;
		if (!g.TestMobjLocation()) { g.Destroy(); return; }
		if (p) { g.target = p; g.angle = g.AngleTo(p); g.SetStateLabel("See"); }
		for (int i = 0; i < 6; i++)
		{
			let s = Spawn("GreedGoo", g.pos + (frandom(-10, 10), frandom(-10, 10), frandom(0, 40)));
			if (s) s.vel = (frandom(-2, 2), frandom(-2, 2), frandom(1, 3));
		}
		g.A_StartSound("greed/sight", CHAN_VOICE);
	}

	void A_RiftBreak()
	{
		A_StopSound(CHAN_BODY);
		A_Scream();
		for (int n = 0; n < 26; n++)
		{
			let d = Spawn("ObsidianDebris", pos + (frandom(-60, 60), frandom(-20, 20), frandom(10, 180)));
			if (d) d.vel = (frandom(-7, 7), frandom(-7, 7), frandom(3, 11));
		}
		Blast.Boom(self, 90, 220, true);
		let k = BlockshireHandler.Get();
		if (k) k.RiftBroken(self);
	}

	States
	{
	Spawn:
		PRTL ABCDEFGHIJKLMNOP 2;
		Loop;
	Death:
		PRTL A 0 A_RiftBreak;
		PRTL AB 3 A_SetScale(scale.x * 0.85);
		PRTL C 0 { SetOrigin(pos + (0, 0, 70), false); Blast.Boom(self, 0, 0, false); SetOrigin(pos - (0, 0, 70), false); }
		PRTL CDEFGH 2 A_SetScale(scale.x * 0.75);
		TNT1 A 0 A_RemoveLight("riftglow");
		TNT1 A -1;
		Stop;
	}
}
