// The Monarch is a cat: every weapon is a paw. It flicks gold coins (spending money to make money),
// shoves Minecraft TNT, or just swats.

class PawSwat : Fist replaces Fist
{
	Default
	{
		Weapon.SlotNumber 1;
		Tag "Royal Paw";
		Obituary "%o was swatted off the table.";
		+WEAPON.MELEEWEAPON
	}
	States
	{
	Ready:
		PAWF C 1 A_WeaponReady;
		Loop;
	Deselect:
		PAWF C 1 A_Lower;
		Loop;
	Select:
		PAWF C 1 A_Raise;
		Loop;
	Fire:
		PAWF C 3;
		PAWF B 4 A_CustomPunch(random(12, 22), true, 0, "SwatPuff", 72);
		PAWF C 6;
		PAWF C 3 A_ReFire;
		Goto Ready;
	}
}

class SwatPuff : BulletPuff
{
	Default
	{
		+PUFFONACTORS
		AttackSound "greed/attack";
		SeeSound "greed/attack";
		ActiveSound "greed/attack";
	}
	States
	{
	Spawn:
	Melee:
		MCSM ABCD 2;
		Stop;
	}
}

class CoinFlick : Pistol replaces Pistol
{
	Default
	{
		Weapon.SlotNumber 2;
		Weapon.AmmoType "Coins";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 25;
		Weapon.SelectionOrder 1900;
		Inventory.PickupMessage "The Royal Coin Flick! (a paw and a purse)";
		Tag "Royal Coin Flick";
		Obituary "%o was paid off by %k.";
	}
	States
	{
	Spawn:
		COIN A -1;
		Stop;
	Ready:
		PAWF A 1 A_WeaponReady;
		Loop;
	Deselect:
		PAWF A 1 A_Lower;
		Loop;
	Select:
		PAWF A 1 A_Raise;
		Loop;
	Fire:
		PAWF A 2;
		PAWF B 3
		{
			A_StartSound("coin/shot", CHAN_WEAPON);
			A_FireProjectile("CoinShot", frandom(-1.5, 1.5), true, 0, 4);
		}
		PAWF C 4;
		PAWF A 3 A_ReFire;
		Goto Ready;
	}
}

// A flicked coin: spins, leaves a glint trail, rings on impact, and sometimes falls back as a coin to pick up.
class CoinShot : Actor
{
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 30;
		Scale 0.85;
		DamageFunction (11 + random(0, 7));
		DeathSound "coin/hit";
		+BRIGHT
		Obituary "%o was paid off by %k.";
	}
	States
	{
	Spawn:
		COIN ABCDEFGH 1
		{
			for (int i = 0; i < 2; i++)
			{
				let s = Spawn("GoldSparkle", pos - vel * frandom(0, 0.5) + (frandom(-3, 3), frandom(-3, 3), frandom(-3, 3)));
				if (s) { s.vel = -vel * 0.04; s.scale *= 1.3; }
			}
		}
		Loop;
	Death:
	XDeath:
	Crash:
		TNT1 A 0
		{
			for (int i = 0; i < 12; i++)
			{
				let s = Spawn("GoldSparkle", pos);
				if (s) { s.vel = (frandom(-4, 4), frandom(-4, 4), frandom(-1, 5)); s.scale *= 1.5; }
			}
			let f = Spawn("CoinFlash", pos);
			// Kingdom economy: a thrown coin is not always lost.
			if (random(0, 99) < 40)
			{
				let c = GoldCoin(Spawn("GoldCoin", pos - vel.Unit() * 12));
				if (c) { c.vel = (frandom(-2, 2), frandom(-2, 2), frandom(2, 4)); c.magnetDelay = 12; c.bDropped = true; }
			}
		}
		TNT1 A 1 A_AttachLight("coinflash", DynamicLight.PointLight, Color(255, 210, 60), 40, 40);
		Stop;
	}
}

// Minecraft TNT, shoved by the paw: lobbed, bounces, flashes white on its fuse, then blows up blocks.
class TNTAmmo : RocketAmmo replaces RocketAmmo
{
	Default
	{
		Inventory.Amount 2;
		Inventory.MaxAmount 50;
		Ammo.BackpackAmount 2;
		Ammo.BackpackMaxAmount 100;
		Inventory.Icon "TNTBA0";
		Inventory.PickupMessage "Picked up some TNT.";
		Tag "TNT";
		Scale 0.5;
		Radius 12;
		Height 32;
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	}
}

class TNTCrate : TNTAmmo replaces RocketBox
{
	Default
	{
		Inventory.Amount 6;
		Inventory.PickupMessage "Picked up a stack of TNT.";
	}
}

class TNTSwat : RocketLauncher replaces RocketLauncher
{
	Default
	{
		Weapon.SlotNumber 5;
		Weapon.AmmoType "TNTAmmo";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 6;
		Inventory.PickupMessage "You got the TNT Shove! Push it off the table.";
		Tag "TNT Shove";
		Scale 0.5;
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	Ready:
		PAWT A 1 A_WeaponReady;
		Loop;
	Deselect:
		PAWT A 1 A_Lower;
		Loop;
	Select:
		PAWT A 1 A_Raise;
		Loop;
	Fire:
		PAWT A 4;
		PAWT B 6
		{
			A_StartSound("tnt/fuse", CHAN_WEAPON);
			A_FireProjectile("ThrownTNT", 0, true, 0, 6, 0, -6);
		}
		PAWF C 8;
		PAWT A 10 A_ReFire;
		Goto Ready;
	}
}

class ThrownTNT : Actor
{
	int fuse;

	Default
	{
		Projectile;
		-NOGRAVITY
		Gravity 0.55;
		Speed 21;
		Radius 10;
		Height 18;
		Scale 0.5;
		BounceType "Doom";
		BounceFactor 0.35;
		WallBounceFactor 0.4;
		BounceCount 6;
		BounceSound "coin/drop";
		DamageFunction (25);
		Obituary "%o was shoved off the table with TNT by %k.";
	}
	States
	{
	Spawn:
		TNTB A 3 A_TNTFuse;
		TNTB B 3 Bright A_TNTFuse;
		Loop;
	Death:
	XDeath:
		TNT1 A 0 { Blast.Boom(self, 140, 200); }
		TNT1 A 2 A_AttachLight("boomflash", DynamicLight.PointLight, Color(255, 220, 160), 260, 260);
		TNT1 A 8 A_AttachLight("boomflash", DynamicLight.PointLight, Color(255, 140, 60), 160, 160);
		Stop;
	}

	void A_TNTFuse()
	{
		fuse += 3;
		let s = Spawn("MCSmoke", pos + (0, 0, 16));
		if (s) { s.vel = (frandom(-0.4, 0.4), frandom(-0.4, 0.4), 1.2); s.scale *= 0.6; }
		if (fuse >= 54) SetStateLabel("Death");
	}
}

// The big Minecraft explosion: grey puffs, a flash, flying blocks, shaking ground.
class Blast play
{
	static void Boom(Actor src, int dmg, double radius, bool hurt = true)
	{
		if (hurt) src.A_Explode(dmg, radius, XF_HURTSOURCE, true, radius * 0.25);
		src.A_StartSound("tnt/boom", CHAN_AUTO, CHANF_DEFAULT, 1.0, 0.4);
		src.A_Quake(4, 14, 0, 900, "");
		for (int i = 0; i < 7; i++)
		{
			let e = Actor.Spawn("MCExplosion", src.pos + (frandom(-40, 40), frandom(-40, 40), frandom(4, 50)));
			if (e) { e.scale *= frandom(1.0, 1.8); e.tics = random(1, 4); }
		}
		for (int i = 0; i < 12; i++)
		{
			let d = Actor.Spawn(i % 3 ? "BlockDebris" : "StoneDebris", src.pos + (0, 0, 12));
			if (d) d.vel = (frandom(-7, 7), frandom(-7, 7), frandom(5, 12));
		}
		for (int i = 0; i < 8; i++)
		{
			let s = Actor.Spawn("MCSmoke", src.pos + (frandom(-48, 48), frandom(-48, 48), frandom(10, 60)));
			if (s) s.vel = (frandom(-1, 1), frandom(-1, 1), frandom(0.5, 2));
		}
	}
}

class CoinFlash : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		RenderStyle "Add";
		Scale 1.4;
	}
	States
	{
	Spawn:
		GSPK ABCD 1;
		GSPK EFGH 1 A_FadeOut(0.2);
		Stop;
	}
}

class MCExplosion : Actor
{
	Default
	{
		+NOINTERACTION
		+BRIGHT
		Scale 1.4;
	}
	States
	{
	Spawn:
		MCEX ABCDEFGHIJKLMNOP 2;
		Stop;
	}
}

class MCSmoke : Actor
{
	Default
	{
		+NOINTERACTION
		Scale 1.2;
	}
	States
	{
	Spawn:
		MCSM ABCDEFGH 4;
		Stop;
	}
}

class BlockDebris : Actor
{
	Default
	{
		Radius 3;
		Height 4;
		+NOBLOCKMAP
		+MOVEWITHSECTOR
		+DROPOFF
		+NOTELEPORT
		-SOLID
		Gravity 0.8;
		BounceType "Doom";
		BounceFactor 0.3;
		BounceCount 3;
		Scale 0.6;
	}
	States
	{
	Spawn:
		DEBR ABCD 3;
		Loop;
	Death:
		DEBR A 40;
		DEBR A 1 A_FadeOut(0.1);
		Wait;
	}
}

class StoneDebris : BlockDebris
{
	States
	{
	Spawn:
		DEBS ABCD 3;
		Loop;
	Death:
		DEBS A 40;
		DEBS A 1 A_FadeOut(0.1);
		Wait;
	}
}

class ObsidianDebris : BlockDebris
{
	Default
	{
		Scale 1.0;
	}
	States
	{
	Spawn:
		DEBO ABCD 3;
		Loop;
	Death:
		DEBO A 60;
		DEBO A 1 A_FadeOut(0.1);
		Wait;
	}
}

// Exploding barrels become TNT blocks: shoot one next to the Greed.
class TNTBlock : ExplosiveBarrel replaces ExplosiveBarrel
{
	Default
	{
		Health 20;
		Radius 16;
		Height 32;
		Scale 0.5;
		DeathSound "tnt/fuse";
		Obituary "%o stood next to the TNT.";
		Tag "TNT block";
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	Death:
		TNTB B 4 Bright A_Scream;
		TNTB A 4;
		TNTB B 4 Bright;
		TNTB A 3;
		TNTB B 3 Bright;
		TNT1 A 0 A_NoBlocking;
		TNT1 A 0 { Blast.Boom(self, 128, 180); }
		TNT1 A 3 A_AttachLight("boomflash", DynamicLight.PointLight, Color(255, 220, 160), 240, 240);
		TNT1 A 6 A_AttachLight("boomflash", DynamicLight.PointLight, Color(255, 140, 60), 150, 150);
		Stop;
	}
}
