// The Kingdom economy: gold coins in a purse, coins that bounce, glint and come back to the Monarch.

class Coins : Ammo
{
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 999;
		Ammo.BackpackAmount 0;
		Inventory.Icon "COINA0";
		Inventory.PickupSound "coin/pick";
		Inventory.PickupMessage "";
		+INVENTORY.IGNORESKILL
		Tag "Coins";
	}
	States
	{
	Spawn:
		COIN A -1;
		Stop;
	}
}

// A coin lying in the world: spins, falls with a clink, drifts to a nearby Monarch (Kingdom's coin pickup feel).
class GoldCoin : Coins
{
	int magnetDelay;   // tics before the purse pulls it back (spilled coins first fly out)
	bool airborne;

	Default
	{
		Inventory.Amount 1;
		Radius 10;
		Height 12;
		Scale 0.7;
		+BRIGHT
		-NOGRAVITY
		Gravity 0.7;
		+INVENTORY.NEVERRESPAWN
		Tag "Gold coin";
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || Owner) return;
		if (pos.z > floorz + 1) airborne = true;
		else if (airborne)
		{
			airborne = false;
			A_StartSound("coin/drop", CHAN_BODY, CHANF_DEFAULT, 0.5);
			vel.xy *= 0.3;
		}
		if (magnetDelay > 0) { magnetDelay--; return; }
		let p = players[consoleplayer].mo;
		if (p && p.health > 0)
		{
			double d = Distance2D(p);
			if (d < 112 && d > 1)
			{
				Vector2 dir = (p.pos.xy - pos.xy) / d;
				vel.xy = dir * 7;
			}
		}
	}

	States
	{
	Spawn:
		COIN ABCDEFGH 3;
		Loop;
	}
}

// Gold glint left by flying coins.
class GoldSparkle : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		RenderStyle "Add";
		Scale 0.6;
		Alpha 0.9;
	}
	States
	{
	Spawn:
		GSPK A 2;
		GSPK A 1 A_FadeOut(0.15);
		Wait;
	}
}

// A coin tossed in an arc to a vagrant: the Kingdom "drop a coin to hire" moment, aimed and timed.
class TossedCoin : Actor
{
	Actor dest;
	int flight, total;

	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 0.5;
	}

	static TossedCoin Throw(Actor from, Actor to, int tics)
	{
		let c = TossedCoin(Actor.Spawn("TossedCoin", from.pos + (0, 0, from.height * 0.7)));
		if (!c) return null;
		c.dest = to;
		c.total = tics;
		Vector3 d = to.pos + (0, 0, to.height * 0.75) - c.pos;
		double g = 0.8;
		c.vel = (d.x / tics, d.y / tics, d.z / tics + 0.5 * g * tics);
		c.A_StartSound("coin/shot", CHAN_BODY, CHANF_DEFAULT, 0.6);
		return c;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed) return;
		vel.z -= 0.8;
		if (level.maptime % 2 == 0) Spawn("GoldSparkle", pos);
		if (++flight >= total)
		{
			let v = Vagrant(dest);
			if (v) v.CatchCoin();
			Destroy();
		}
	}

	States
	{
	Spawn:
		COIN ABCDEFGH 1;
		Loop;
	}
}

// Spills coins out of the Monarch's purse when a Greed lands a hit.
class CoinSpill play
{
	static void Burst(Actor at, int n, bool fromPurse = true)
	{
		for (int i = 0; i < n; i++)
		{
			let c = GoldCoin(Actor.Spawn("GoldCoin", at.pos + (0, 0, at.height * 0.6)));
			if (!c) continue;
			double a = frandom(0, 360);
			c.vel = (cos(a) * frandom(3, 6), sin(a) * frandom(3, 6), frandom(5, 8));
			c.magnetDelay = fromPurse ? 45 : 20;
			c.bDropped = true;
		}
		if (n > 0) at.A_StartSound(fromPurse ? "coin/spill" : "coin/drop", CHAN_AUTO);
	}
}
