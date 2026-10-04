// Blockshire: the realm's rules. Day and night with a Blood Moon, Greed burning at dawn, hiring vagrants
// with the purse, the crown that can be stolen, the quests, the cat's running commentary and the HUD.

class BlockshireHandler : EventHandler
{
	const T_CYCLE = 35 * 110;       // one day: day 60 s, dusk 5 s, Blood Moon 38 s, dawn 7 s
	const T_DUSK = 35 * 60;
	const T_NIGHT = 35 * 65;
	const T_DAWN = 35 * 103;
	const T_FIRST = 35 * 22;         // the first day is short: the Blood Moon rises 22 s in

	Array<Actor> greed;
	Array<Vagrant> vagrants;
	Array<GreedPortal> portals;
	Array<int> baseLight;
	int hiredCount, portalsBroken, portalsTotal, nightsSurvived, day, riftsSealed;
	int crownState;                // 0 worn, 1 stolen, 2 on the ground
	Actor thief;
	int thiefSince;
	bool wasNight, victory, realm, nightSky;
	double dayLevel;               // 1 = full day, 0 = Blood Moon
	String line, noticeText;
	int lineAt, noticeAt, bannerAt;
	String bannerText;
	Array<String> queue;
	Array<int> queueAt;
	int lastSaid;

	static BlockshireHandler Get() { return BlockshireHandler(EventHandler.Find("BlockshireHandler")); }

	// ---------------------------------------------------------------- the cat talks
	void Say(String s, bool meow = true)
	{
		line = s;
		lineAt = level.maptime;
		let p = players[consoleplayer].mo;
		if (meow && p) p.A_StartSound("cat/meow", CHAN_VOICE, CHANF_DEFAULT, 0.9);
	}

	void SayLater(String s, int delay)
	{
		queue.Push(s);
		queueAt.Push(level.maptime + delay);
	}

	void Notice(String s)
	{
		noticeText = s;
		noticeAt = level.maptime;
	}

	void Banner(String s)
	{
		bannerText = s;
		bannerAt = level.maptime;
	}

	// ---------------------------------------------------------------- world
	// In every map the zombies and imps are Greedlings, the pinkies Crown Stealers.
	override void CheckReplacement(ReplaceEvent e)
	{
		Name r = e.Replacee.GetClassName();
		if (r == 'ZombieMan' || r == 'ShotgunGuy' || r == 'DoomImp' || r == 'ChaingunGuy') e.Replacement = "Greedling";
		else if (r == 'Demon' || r == 'Spectre') e.Replacement = "GreedBrute";
	}

	override void WorldLoaded(WorldEvent e)
	{
		realm = level.MapName ~== "MAP01";
		for (int i = 0; i < level.Sectors.Size(); i++) baseLight.Push(level.Sectors[i].lightlevel);
		if (!realm) Minecraftify();
		dayLevel = 1;
		day = 1;
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		let t = e.Thing;
		if (!t) return;
		if (t is "Greedling") greed.Push(t);
		else if (t is "Vagrant") vagrants.Push(Vagrant(t));
		else if (t is "GreedPortal") { portals.Push(GreedPortal(t)); portalsTotal++; }
	}

	override void WorldThingDied(WorldEvent e)
	{
		let t = e.Thing;
		if (!t) return;
		if (t == thief && crownState == 1)
		{
			crownState = 2;
			let p = players[consoleplayer].mo;
			if (p) ReturningCrown.Fly(t, p);
			Say("Thief down. Come back to me, my precious crown!");
			thief = null;
		}
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let p = players[e.PlayerNumber].mo;
		if (!p) return;
		// The Monarch is a cat: paws instead of fists and pistols.
		p.TakeInventory("Pistol", 1);
		p.TakeInventory("Fist", 1);
		p.GiveInventory("PawSwat", 1);
		p.GiveInventory("CoinFlick", 1);
		p.TakeInventory("Clip", 999);
		if (p.CountInv("Coins") < 30) p.GiveInventory("Coins", 30 - p.CountInv("Coins"));
		p.A_SelectWeapon("CoinFlick");
		realm = level.MapName ~== "MAP01";   // PlayerEntered can come before WorldLoaded
		if (realm)
		{
			Banner("BLOCKSHIRE");
			Say("I am Sir Whiskers, a SuperIntelligent Cat, Monarch of Blockshire.");
			SayLater("Rule one: coins buy loyalty. Walk up to a vagrant and I pay.", 35 * 5);
			SayLater("Rule two: the Greed want my crown. Smash their portals.", 35 * 11);
		}
		else Say("This place needed more blocks. Fixed it.");
	}

	clearscope bool HasCrown() { return crownState == 0; }

	clearscope bool IsNight()
	{
		int t = Phase();
		return t >= T_NIGHT && t < T_DAWN;
	}

	clearscope int Phase()
	{
		return (level.maptime + sigf_timeshift * 35 + (T_DUSK - T_FIRST)) % T_CYCLE;
	}

	int GreedCount()
	{
		int n = 0;
		for (int i = 0; i < greed.Size(); i++) if (greed[i] && greed[i].health > 0) n++;
		return n;
	}

	static Actor NearestGreed(Actor from, double range)
	{
		let k = Get();
		if (!k) return null;
		Actor best = null;
		double bd = range;
		for (int i = 0; i < k.greed.Size(); i++)
		{
			let g = k.greed[i];
			if (!g || g.health <= 0) continue;
			double d = from.Distance2D(g);
			if (d < bd && from.CheckSight(g)) { bd = d; best = g; }
		}
		return best;
	}

	void Hired(Actor archer)
	{
		hiredCount++;
		if (hiredCount == 1) Say("One coin, one archer. Humans are so cheap.");
		else if (hiredCount == 3) Say("Three archers! I am basically a general now.");
		else if (hiredCount == 5) Say("My army grows. My nap schedule shrinks.");
		else Notice("A vagrant took your coin and picked up a bow.");
	}

	void StealCrown(Actor by)
	{
		if (crownState != 0) return;
		crownState = 1;
		thief = by;
		thiefSince = level.maptime;
		let c = Actor.Spawn("StolenCrown", by.pos + (0, 0, by.height));
		if (c) c.master = by;
		by.bFrightened = true;
		by.speed *= 0.6;    // a crown is heavy
		if (by.health > 70) by.health = 70;
		by.SetStateLabel("Gloat");
		by.A_StartSound("kingdom/crown", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
		Banner("CROWN STOLEN!");
		Say("THEY TOOK MY CROWN. And now it is admiring it. Get that thief!");
	}

	void CrownBack()
	{
		crownState = 0;
		thief = null;
		Banner("THE CROWN IS BACK");
		Say("Crown restored. Order restored. Nap... postponed.");
	}

	bool RiftOpen()
	{
		let it = ThinkerIterator.Create("RiftPortal");
		Actor r;
		while (r = Actor(it.Next())) if (r.health > 0) return true;
		return false;
	}

	void RiftBroken(Actor r)
	{
		riftsSealed++;
		Banner("GREED PORTAL SMASHED!");
		Say("Knocked that portal right off the table. Cats do that.");
	}

	// Each Blood Moon tears a rift open in the open fields near the Monarch.
	void OpenRift(PlayerPawn p)
	{
		for (int k = 0; k < 40; k++)
		{
			double a = p.angle + (k < 20 ? frandom(-30, 30) : frandom(-180, 180));
			Vector2 xy = p.Vec2Angle(frandom(380, 540), a);
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - p.pos.z) > 24) continue;
			let r = Actor.Spawn("RiftPortal", (xy, z));
			if (!r) continue;
			if (!r.TestMobjLocation() || !p.CheckSight(r)) { r.Destroy(); continue; }
			for (int i = 0; i < 16; i++)
			{
				let g = Actor.Spawn("GreedGoo", r.pos + (frandom(-50, 50), frandom(-50, 50), frandom(0, 160)));
				if (g) g.vel = (frandom(-3, 3), frandom(-3, 3), frandom(1, 4));
			}
			Banner("A GREED PORTAL TEARS OPEN!");
			SayLater("A portal in my fields? Rude. Smash it before it floods us.", 50);
			return;
		}
	}

	void PortalBroken(GreedPortal p)
	{
		portalsBroken++;
		if (portalsBroken >= portalsTotal && portalsTotal > 0)
		{
			victory = true;
			Banner("BLOCKSHIRE IS SAFE");
			let pl = players[consoleplayer].mo;
			if (pl) pl.A_StartSound("kingdom/victory", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			Say("Both portals smashed. I will now nap for sixteen hours. Do not disturb.");
		}
		else
		{
			Banner("PORTAL SMASHED " .. portalsBroken .. "/" .. portalsTotal);
			Say("Knocked it right off the table. One more portal to go.");
		}
	}

	// ---------------------------------------------------------------- the clock
	override void WorldTick()
	{
		let p = players[consoleplayer].mo;
		if (!p) return;

		for (int i = 0; i < queue.Size(); i++)
		{
			if (level.maptime >= queueAt[i]) { Say(queue[i]); queue.Delete(i); queueAt.Delete(i); break; }
		}
		if (level.maptime % 70 == 0)
		{
			for (int i = greed.Size() - 1; i >= 0; i--) if (!greed[i]) greed.Delete(i);
			for (int i = vagrants.Size() - 1; i >= 0; i--) if (!vagrants[i]) vagrants.Delete(i);
		}

		if (realm && !sigf_nodaynight) DayNight(p);
		if (realm && IsNight() && level.maptime % (35 * 4) == 0 && GreedCount() < 12 && !RiftOpen()) NightRaid(p);

		// Hiring: the purse pays any vagrant the Monarch walks up to.
		if (level.maptime % 5 == 0 && p.health > 0)
		{
			for (int i = 0; i < vagrants.Size(); i++)
			{
				let v = vagrants[i];
				if (!v || v.hired || p.CountInv("Coins") < 1) continue;
				if (p.Distance2D(v) < 230 && p.CheckSight(v))
				{
					p.TakeInventory("Coins", 1);
					v.Hire(p);
					break;
				}
			}
		}

		// The crown thief escapes into a portal after a while (luckily cats keep a spare).
		if (crownState == 1 && (!thief || level.maptime - thiefSince > 35 * 30))
		{
			if (thief) thief.Destroy();
			thief = null;
			crownState = 0;
			Say("The thief got away. Good thing I keep a spare crown under the bed.");
		}
	}

	// Blood Moon raids: Greed crawl out of the dark a little way off, on the side of the nearest portal.
	void NightRaid(PlayerPawn p)
	{
		GreedPortal near = null;
		for (int i = 0; i < portals.Size(); i++)
			if (portals[i] && portals[i].health > 0 && (!near || p.Distance2D(portals[i]) < p.Distance2D(near))) near = portals[i];
		double base = p.angle;   // out of the dark, ahead of the Monarch
		int n = random(1, 2);
		for (int k = 0; k < 12 && n > 0; k++)
		{
			Vector2 xy = p.Vec2Angle(frandom(420, 650), base + frandom(-60, 60));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - p.pos.z) > 40) continue;
			let g = Actor.Spawn(random(0, 5) ? "Greedling" : "GreedBrute", (xy, z));
			if (!g) continue;
			if (!g.TestMobjLocation()) { g.Destroy(); continue; }
			g.target = p;
			g.angle = g.AngleTo(p);
			g.SetStateLabel("See");
			for (int i = 0; i < 6; i++)
			{
				let s = Actor.Spawn("GreedGoo", g.pos + (frandom(-10, 10), frandom(-10, 10), frandom(0, 40)));
				if (s) s.vel = (frandom(-2, 2), frandom(-2, 2), frandom(1, 3));
			}
			n--;
		}
	}

	void DayNight(PlayerPawn p)
	{
		int t = Phase();
		double want;
		if (t < T_DUSK) want = 1;
		else if (t < T_NIGHT) want = 1 - double(t - T_DUSK) / (T_NIGHT - T_DUSK);
		else if (t < T_DAWN) want = 0;
		else want = double(t - T_DAWN) / (T_CYCLE - T_DAWN);
		bool night = t >= T_NIGHT && t < T_DAWN;

		if (t == T_NIGHT + 35) OpenRift(p);
		if (t == T_DUSK)
		{
			p.A_StartSound("kingdom/horn", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			Banner("THE BLOOD MOON RISES");
			Say("Blood Moon. The Greed are coming for my coins. Mostly my coins.");
		}
		bool wantNightSky = t >= (T_DUSK + T_NIGHT) / 2 && t < (T_DAWN + T_CYCLE) / 2;
		if (wantNightSky != nightSky)
		{
			nightSky = wantNightSky;
			TextureID sky = TexMan.CheckForTexture(nightSky ? "BSKYNGT" : "BSKYDAY", TexMan.Type_Any);
			level.ChangeSky(sky, sky);
		}
		if (t == T_DAWN)
		{
			p.A_StartSound("kingdom/dawn", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			Banner("DAWN");
			Say("Sunrise! The Greed burn in daylight. It is a block world thing.");
			nightsSurvived++;
			day++;
			for (int i = 0; i < greed.Size(); i++)
			{
				let g = Greedling(greed[i]);
				if (!g || g.health <= 0 || g.burning) continue;
				g.burning = true;
				let f = Actor.Spawn("SunFire", g.pos);
				if (f) f.master = g;
			}
		}

		if (abs(want - dayLevel) > 0.001 || level.maptime < 3)
		{
			dayLevel = want;
			int r = 255, g = int(170 + 85 * dayLevel), b = int(185 + 70 * dayLevel);
			for (int i = 0; i < level.Sectors.Size() && i < baseLight.Size(); i++)
			{
				let s = level.Sectors[i];
				s.SetLightLevel(int(baseLight[i] * (0.76 + 0.24 * dayLevel)));
				s.SetColor(Color(r, g, b));
			}
		}
		wasNight = night;
	}

	// ---------------------------------------------------------------- every other map: blocks
	void Minecraftify()
	{
		for (int i = 0; i < level.Sides.Size(); i++)
		{
			let sd = level.Sides[i];
			for (int k = 0; k < 3; k++)
			{
				TextureID tx = sd.GetTexture(k);
				if (!tx.IsValid() || tx.IsNull()) continue;
				String n = TexMan.GetName(tx);
				String m = WallBlock(n);
				if (m != "") sd.SetTexture(k, TexMan.CheckForTexture(m, TexMan.Type_Any));
			}
		}
		for (int i = 0; i < level.Sectors.Size(); i++)
		{
			let s = level.Sectors[i];
			for (int k = 0; k < 2; k++)
			{
				TextureID tx = s.GetTexture(k);
				String n = TexMan.GetName(tx);
				if (n.IndexOf("SKY") >= 0) continue;
				String m = FlatBlock(n, k == Sector.ceiling);
				if (m != "") s.SetTexture(k, TexMan.CheckForTexture(m, TexMan.Type_Any));
			}
		}
		level.ChangeSky(TexMan.CheckForTexture("BSKYDAY", TexMan.Type_Any), TexMan.CheckForTexture("BSKYDAY", TexMan.Type_Any));
	}

	static bool Has(String n, String k) { return n.IndexOf(k) >= 0; }

	static String WallBlock(String n)
	{
		n = n.MakeUpper();
		if (Has(n, "SW1") || Has(n, "SW2") || Has(n, "EXIT") || Has(n, "SKY")) return "";
		if (Has(n, "BRICK")) return "MCBRICK";
		if (Has(n, "WOOD") || Has(n, "PANEL") || Has(n, "DOOR")) return "MCPLANK";
		if (Has(n, "MARB") || Has(n, "GSTON") || Has(n, "SKIN") || Has(n, "FIRE")) return "MCOBSID";
		if (Has(n, "ROCK") || Has(n, "STONE") || Has(n, "CEMENT")) return "MCCOBBLE";
		if (Has(n, "BROWN") || Has(n, "ASH")) return "MCDIRT";
		if (Has(n, "COMP") || Has(n, "TEK") || Has(n, "SILVER") || Has(n, "METAL") || Has(n, "SUPPORT") || Has(n, "PIPE")) return "MCSTBRK";
		if (Has(n, "GRAY") || Has(n, "STAR") || Has(n, "SHAWN")) return "MCSTONE";
		if (Has(n, "GREEN") || Has(n, "VINE")) return "MCMOSSY";
		if (Has(n, "LITE") || Has(n, "LIGHT")) return "MCGLASS";
		if (Has(n, "BOOK")) return "MCBOOK";
		return "MCCOBBLE";
	}

	static String FlatBlock(String n, bool ceil)
	{
		n = n.MakeUpper();
		if (Has(n, "NUKAGE") || Has(n, "FWATER") || Has(n, "SLIME")) return "MCWATER";
		if (Has(n, "LAVA") || Has(n, "BLOOD")) return "MCLAVA";
		if (Has(n, "GRASS") || Has(n, "RROCK19")) return "MCGRASS";
		if (Has(n, "LITE") || Has(n, "TLITE")) return "MCGLASS";
		if (Has(n, "WOOD") || Has(n, "FLAT5")) return "MCPLANK";
		if (Has(n, "MFLR") || Has(n, "RROCK") || Has(n, "FLOOR7")) return "MCDIRT";
		return ceil ? "MCSTONE" : "MCPLANK";
	}

	// ---------------------------------------------------------------- HUD
	const VW = 640;
	const VH = 360;

	ui void TextS(Font f, int col, double x, double y, String s, double sc, double alpha = 1, bool centre = false)
	{
		// scaled text: draw in a smaller virtual screen
		double vw = VW / sc, vh = VH / sc;
		x /= sc; y /= sc;
		if (centre) x -= f.StringWidth(s) / 2;
		Screen.DrawText(f, Font.CR_BLACK, x + 1, y + 1, s, DTA_VirtualWidthF, vw, DTA_VirtualHeightF, vh, DTA_KeepRatio, true, DTA_Alpha, alpha * 0.8);
		Screen.DrawText(f, col, x, y, s, DTA_VirtualWidthF, vw, DTA_VirtualHeightF, vh, DTA_KeepRatio, true, DTA_Alpha, alpha);
	}

	ui void Pic(String name, double x, double y, double sc, double alpha = 1)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return;
		Screen.DrawTexture(t, false, x / sc, y / sc, DTA_VirtualWidthF, VW / sc, DTA_VirtualHeightF, VH / sc, DTA_KeepRatio, true, DTA_TopLeft, true, DTA_Alpha, alpha);
	}

	override void RenderOverlay(RenderEvent e)
	{
		let p = players[consoleplayer].mo;
		if (!p || automapactive) return;
		int now = level.maptime;
		Font big = BigFont;
		Font sm = NewSmallFont;

		// Purse, top centre: Kingdom shows the coins above the Monarch.
		int coins = p.CountInv("Coins");
		Pic("COINA0", 286, 8, 1.6);
		TextS(sm, Font.CR_GOLD, 316, 12, String.Format("%d", coins), 2.0);
		if (crownState == 0) Pic("CROWA0", 274, 40, 1.0, 1);
		else if ((now / 8) % 2) TextS(sm, Font.CR_RED, 320, 42, "CROWN STOLEN!", 1.0, 1, true);

		// Time of day, top left.
		if (realm)
		{
			int t = Phase();
			String tod;
			int col;
			if (t >= T_NIGHT && t < T_DAWN) { tod = String.Format("BLOOD MOON  - dawn in %ds", (T_DAWN - t) / 35); col = Font.CR_RED; }
			else if (t >= T_DUSK && t < T_NIGHT) { tod = "DUSK"; col = Font.CR_ORANGE; }
			else { int left = (t < T_DUSK ? T_DUSK - t : T_CYCLE - t + T_DUSK) / 35; tod = String.Format("DAY %d  - night in %ds", day, left); col = Font.CR_GOLD; }
			TextS(sm, col, 10, 8, tod, 1.0);

			// Quests, top right.
			double qx = 436, qy = 8;
			TextS(sm, Font.CR_GOLD, qx, qy, "QUESTS OF THE CAT", 0.85);
			TextS(sm, hiredCount >= 3 ? Font.CR_GREEN : Font.CR_WHITE, qx, qy + 11, String.Format("%s Hire 3 archers (%d/3)", hiredCount >= 3 ? "[x]" : "[ ]", min(hiredCount, 3)), 0.8);
			TextS(sm, nightsSurvived >= 1 ? Font.CR_GREEN : Font.CR_WHITE, qx, qy + 21, String.Format("%s Survive the Blood Moon", nightsSurvived >= 1 ? "[x]" : "[ ]"), 0.8);
			TextS(sm, riftsSealed >= 1 ? Font.CR_GREEN : Font.CR_WHITE, qx, qy + 31, String.Format("%s Seal the Blood Moon rift", riftsSealed >= 1 ? "[x]" : "[ ]"), 0.8);
			TextS(sm, portalsBroken >= portalsTotal && portalsTotal ? Font.CR_GREEN : Font.CR_WHITE, qx, qy + 41, String.Format("%s Smash both Greed portals %d/%d", portalsBroken >= portalsTotal && portalsTotal ? "[x]" : "[ ]", portalsBroken, portalsTotal), 0.8);
			TextS(sm, crownState == 0 ? Font.CR_GREEN : Font.CR_RED, qx, qy + 51, crownState == 0 ? "[x] Keep the crown" : "[ ] GET THE CROWN BACK", 0.8);

			// Nearest portal's health.
			Array<Actor> gates;
			for (int i = 0; i < portals.Size(); i++) gates.Push(portals[i]);
			let rit = ThinkerIterator.Create("RiftPortal");
			Actor ra;
			while (ra = Actor(rit.Next())) gates.Insert(0, ra);
			for (int i = 0; i < gates.Size(); i++)
			{
				let gp = gates[i];
				if (!gp || gp.health <= 0 || p.Distance2D(gp) > 1000) continue;
				double frac = gp.health / double(gp.GetSpawnHealth());
				TextS(sm, Font.CR_PURPLE, 436, 70, "GREED PORTAL", 0.8);
				int w = Screen.GetWidth(), h = Screen.GetHeight();
				double vx = w / 2.0 - h * 16.0 / 9.0 / 2.0;   // the 640x360 virtual box, centred
				double u = h / 360.0;
				Screen.Dim(Color(0, 0, 0), 0.7, int(vx + 436 * u), int(82 * u), int(160 * u), int(6 * u));
				Screen.Dim(Color(200, 40, 255), 0.95, int(vx + 436 * u), int(82 * u), int(160 * u * frac), int(6 * u));
				break;
			}
		}

		// The cat speaks, bottom left: portrait + line.
		if (line != "" && now - lineAt < 35 * 6)
		{
			double a = min(1.0, (35 * 6 - (now - lineAt)) / 20.0);
			int w = Screen.GetWidth(), h = Screen.GetHeight();
			Screen.Dim(Color(20, 10, 30), 0.6 * a, int(w * 0.02), int(h * 0.80), int(w * 0.62), int(h * 0.11));
			Pic(crownState == 0 ? "CATCA1" : "CATKA1", 16, 280, 0.75, a);
			TextS(sm, Font.CR_GOLD, 84, 292, "Sir Whiskers:", 1.0, a);
			TextS(sm, Font.CR_WHITE, 84, 304, line, 1.0, a);
		}
		if (noticeText != "" && now - noticeAt < 35 * 3)
			TextS(sm, Font.CR_ORANGE, 320, 64, noticeText, 1.0, min(1.0, (35 * 3 - (now - noticeAt)) / 15.0), true);
		if (bannerText != "" && now - bannerAt < 35 * 4)
		{
			double a = min(1.0, (35 * 4 - (now - bannerAt)) / 20.0);
			TextS(sm, bannerText.IndexOf("BLOOD") >= 0 || bannerText.IndexOf("STOLEN") >= 0 ? Font.CR_RED : Font.CR_GOLD, 320, 100, bannerText, 2.6, a, true);
		}
	}
}
