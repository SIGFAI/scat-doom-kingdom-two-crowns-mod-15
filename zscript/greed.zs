// The Greed, in blocks: masked thieves from the portals. They hit the purse first (coins fly out),
// and when the purse is empty, or a Crown Stealer gets close, they take the crown.

class GreedGoo : Blood
{
	Default
	{
		+NOINTERACTION
		Scale 0.7;
	}
	States
	{
	Spawn:
		PURP ABCD 3;
		Stop;
	Spray:
		PURP ABCD 3;
		Stop;
	}
}

// A mask knocked off a dying Greed: spins up and clatters down.
class FlyingMask : Actor
{
	Default
	{
		Radius 4;
		Height 6;
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		Gravity 0.6;
		BounceType "Doom";
		BounceFactor 0.4;
		BounceCount 3;
		BounceSound "greed/mask";
		Scale 0.6;
	}
	States
	{
	Spawn:
		MASK ABCD 3;
		Loop;
	Death:
		MASK A 70;
		MASK A 1 A_FadeOut(0.05);
		Wait;
	}
}

class Greedling : Actor
{
	int carried;       // coins it grabbed
	bool burning;      // caught by the dawn

	Default
	{
		Monster;
		Health 60;
		Radius 14;
		Height 44;
		Speed 9;
		FastSpeed 12;
		Mass 80;
		PainChance 180;
		MeleeRange 50;
		Scale 0.5;
		SeeSound "greed/sight";
		PainSound "greed/pain";
		DeathSound "greed/die";
		ActiveSound "greed/sight";
		BloodType "GreedGoo";
		BloodColor "70 10 110";
		Obituary "%o was mugged by a Greedling.";
		Tag "Greedling";
		+FLOORCLIP
		+DONTHARMSPECIES
	}

	virtual int SwipeLo() { return 3; }
	virtual int SwipeHi() { return 8; }
	virtual bool Stealer() { return false; }

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || health <= 0 || level.maptime % 6) return;
		// Greed love loose coins: grab any within reach.
		let it = BlockThingsIterator.Create(self, 40);
		while (it.Next())
		{
			let c = GoldCoin(it.thing);
			if (c && !c.Owner && Distance3D(c) < 44)
			{
				carried++;
				A_StartSound("coin/pick", CHAN_ITEM, CHANF_DEFAULT, 0.8, ATTN_NORM, 0.7);
				c.Destroy();
			}
		}
	}

	void A_GreedSwipe()
	{
		if (!target) return;
		A_FaceTarget();
		if (!CheckMeleeRange()) return;
		A_StartSound("greed/attack", CHAN_WEAPON);
		target.DamageMobj(self, self, random(SwipeLo(), SwipeHi()), 'Melee');
		if (target) target.Thrust(3, angle);
		if (target && target.player)
		{
			let k = BlockshireHandler.Get();
			int have = target.CountInv("Coins");
			if (Stealer() && k && k.HasCrown()) k.StealCrown(self);
			else if (have > 0)
			{
				int n = min(have, random(2, 4));
				target.TakeInventory("Coins", n);
				CoinSpill.Burst(target, n);
				if (k) k.Notice("The Greed knocked " .. n .. " coins out of your purse!");
			}
			else if (k && k.HasCrown()) k.StealCrown(self);
		}
	}

	// Death: the mask pops off, the body melts into goo, every grabbed coin falls out.
	void A_GreedDeath()
	{
		A_Scream();
		let m = Spawn("FlyingMask", pos + (0, 0, height * 0.85));
		if (m) { m.vel = (frandom(-3, 3), frandom(-3, 3), frandom(6, 9)); m.A_StartSound("greed/mask", CHAN_BODY); }
		for (int i = 0; i < 8; i++)
		{
			let g = Spawn("GreedGoo", pos + (frandom(-8, 8), frandom(-8, 8), frandom(8, height)));
			if (g) g.vel = (frandom(-2, 2), frandom(-2, 2), frandom(0, 3));
		}
		CoinSpill.Burst(self, carried + random(1, 2), false);
		carried = 0;
	}

	void A_Melt()
	{
		let g = Spawn("GreedGoo", pos + (frandom(-12, 12), frandom(-12, 12), 4));
		A_FadeOut(0.04);
	}

	States
	{
	Spawn:
		GRDL A 10 A_Look;
		Loop;
	See:
		GRDL AABBCCDD 2 A_Chase;
		Loop;
	Melee:
		GRDL E 5 A_FaceTarget;
		GRDL F 5 A_GreedSwipe;
		GRDL E 4;
		Goto See;
	Pain:
		GRDL G 3;
		GRDL G 4 A_Pain;
		Goto See;
	Death:
		GRDL G 3 A_GreedDeath;
		GRDL H 4 A_NoBlocking;
		GRDL I 4;
		GRDL J 30;
		GRDL J 2 A_Melt;
		Wait;
	}
}


// The Crown Stealer: bigger, faster, goes straight for the crown.
class GreedBrute : Greedling
{
	Default
	{
		Health 150;
		Radius 20;
		Height 64;
		Speed 12;
		FastSpeed 16;
		Mass 300;
		PainChance 120;
		MeleeRange 60;
		Scale 0.5;
		Obituary "%o lost the crown to a Crown Stealer.";
		Tag "Crown Stealer";
	}
	override int SwipeLo() { return 6; }
	override int SwipeHi() { return 12; }
	override bool Stealer() { return true; }

	// Crown Stealers pounce: a leap closes the last few steps to the Monarch.
	void A_BruteChase()
	{
		A_Chase();
		if (!target || bFrightened || pos.z > floorz + 1) return;
		double d = Distance2D(target);
		// Greed grab what they touch: close enough to the Monarch, the crown is gone.
		let k = BlockshireHandler.Get();
		if (target.player && d < 140 && k && k.HasCrown() && CheckSight(target))
		{
			A_FaceTarget();
			A_StartSound("greed/attack", CHAN_WEAPON);
			target.Thrust(4, angle);
			k.StealCrown(self);
			return;
		}
		if (d < 300 && d > 80 && random(0, 7) == 0)
		{
			A_FaceTarget();
			VelFromAngle(15);
			vel.z = 5;
			A_StartSound("greed/sight", CHAN_VOICE);
		}
	}

	// Just stole the crown: stops to admire it (the Monarch's chance), then runs for it.
	void A_Gloat()
	{
		if (target) A_FaceTarget();
		if (random(0, 2) == 0) A_StartSound("greed/sight", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NORM, 1.3);
	}

	States
	{
	Gloat:
		GRDB E 6 A_Gloat;
		GRDB F 6;
		GRDB E 6 A_Gloat;
		GRDB F 6;
		GRDB E 6 A_Gloat;
		GRDB F 6;
		GRDB E 6 A_Gloat;
		GRDB F 6;
		Goto See;
	Spawn:
		GRDB A 10 A_Look;
		Loop;
	See:
		GRDB AABBCCDD 2 A_BruteChase;
		Loop;
	Melee:
		GRDB E 6 A_FaceTarget;
		GRDB F 5 A_GreedSwipe;
		GRDB E 4;
		Goto See;
	Pain:
		GRDB G 3;
		GRDB G 5 A_Pain;
		Goto See;
	Death:
		GRDB G 3 A_GreedDeath;
		GRDB H 4 A_NoBlocking;
		GRDB I 4;
		GRDB J 30;
		GRDB J 2 A_Melt;
		Wait;
	}
}


// The crown, worn by a thief running back to its portal.
class StolenCrown : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 0.6;
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed) return;
		if (!master || master.health <= 0) { Destroy(); return; }
		SetOrigin(master.pos + (0, 0, master.height + 2), true);
	}
	States
	{
	Spawn:
		CROW ABCD 4;
		Loop;
	}
}

// The crown flies home: out of the fallen thief, in an arc, back onto the Monarch's head.
class ReturningCrown : Actor
{
	Actor home;
	int flight;

	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 1.3;
	}

	static void Fly(Actor from, Actor to)
	{
		let c = ReturningCrown(Actor.Spawn("ReturningCrown", from.pos + (0, 0, from.height)));
		if (!c) return;
		c.home = to;
		c.vel = (0, 0, 7);
		c.A_StartSound("kingdom/recruit", CHAN_BODY);
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed) return;
		flight++;
		if (home)
		{
			Vector3 goal = home.pos + (0, 0, home.height + 8);
			Vector3 d = goal - pos;
			double len = d.Length();
			if (flight > 14) vel = vel * 0.8 + d.Unit() * min(len, 9) * 0.2 + (0, 0, flight < 30 ? 0.8 : 0);
			else vel.z -= 0.4;
			if (len < 24 || flight > 120)
			{
				let k = BlockshireHandler.Get();
				if (k) k.CrownBack();
				for (int i = 0; i < 10; i++)
				{
					let s = Spawn("GoldSparkle", pos + (frandom(-10, 10), frandom(-10, 10), frandom(-6, 6)));
					if (s) s.vel = (frandom(-2, 2), frandom(-2, 2), frandom(0, 3));
				}
				Destroy();
				return;
			}
		}
		for (int i = 0; i < 2; i++)
		{
			let s = Spawn("GoldSparkle", pos + (frandom(-6, 6), frandom(-6, 6), frandom(-4, 8)));
			if (s) s.scale *= 1.4;
		}
	}

	States
	{
	Spawn:
		CROW ABCD 3;
		Loop;
	}
}

// The crown on the ground: walk over it to put it back on.
class CrownPickup : Inventory
{
	Default
	{
		Inventory.PickupMessage "";
		Inventory.PickupSound "kingdom/recruit";
		+INVENTORY.AUTOACTIVATE
		Radius 14;
		Height 16;
		Scale 0.7;
		+BRIGHT
		Gravity 0.6;
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || Owner) return;
		// The crown wants to go home: it rolls toward a nearby Monarch.
		let p = players[consoleplayer].mo;
		if (p && p.health > 0 && Distance2D(p) < 420 && pos.z <= floorz + 2)
			vel.xy = (p.pos.xy - pos.xy).Unit() * 6;
	}

	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher || !toucher.player) return false;
		let k = BlockshireHandler.Get();
		if (k) k.CrownBack();
		GoAwayAndDie();
		return true;
	}
	States
	{
	Spawn:
		CROW ABCD 5;
		Loop;
	}
}

// Dawn in a Minecraft world: the Greed burn in the sunlight.
class SunFire : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 1.1;
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed) return;
		if (!master || master.health <= 0) { Destroy(); return; }
		SetOrigin(master.pos + (0, 0, 2), true);
		if (level.maptime % 12 == 0) master.DamageMobj(self, null, 7, 'Fire');
		if (level.maptime % 5 == 0)
		{
			let s = Spawn("MCSmoke", master.pos + (frandom(-8, 8), frandom(-8, 8), master.height * frandom(0.6, 1.0)));
			if (s) s.vel = (0, 0, frandom(1, 2));
			let f = Spawn("BurnFlame", master.pos + (frandom(-6, 6), frandom(-6, 6), master.height * 0.45));
			if (f) f.vel.z = 0.8;
		}
	}
	States
	{
	Spawn:
		FIRE ABCDEFGH 2;
		Loop;
	}
}

// A short flame licking up a burning Greed.
class BurnFlame : Actor
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
		FIRE ABCDEFGH 2;
		Stop;
	}
}
