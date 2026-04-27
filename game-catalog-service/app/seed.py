import random
import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal

from sqlalchemy.orm import Session

from app.models.game import Category, Game, Review


def seed_data(db: Session):
    if db.query(Game).first() is not None:
        return

    categories = {
        "Action": Category(name="Action"),
        "RPG": Category(name="RPG"),
        "Sports": Category(name="Sports"),
        "Adventure": Category(name="Adventure"),
        "Racing": Category(name="Racing"),
    }
    for cat in categories.values():
        db.add(cat)
    db.flush()

    covers = {
        "Horizon Forbidden West": "https://upload.wikimedia.org/wikipedia/en/6/69/Horizon_Forbidden_West_cover_art.jpg",
        "God of War Ragnarok": "https://upload.wikimedia.org/wikipedia/en/e/ee/God_of_War_Ragnar%C3%B6k_cover.jpg",
        "Spider-Man 2": "https://upload.wikimedia.org/wikipedia/en/0/0f/SpiderMan2PS5BoxArt.jpeg",
        "Final Fantasy XVI": "https://upload.wikimedia.org/wikipedia/en/0/00/Final_Fantasy_XVI_cover_art.png",
        "Elden Ring": "https://upload.wikimedia.org/wikipedia/en/b/b9/Elden_Ring_Box_art.jpg",
        "Persona 5 Royal": "https://upload.wikimedia.org/wikipedia/en/b/b0/Persona_5_cover_art.jpg",
        "EA Sports FC 25": "https://upload.wikimedia.org/wikipedia/en/0/09/EA_FC_25_Cover.jpg",
        "NBA 2K25": "https://upload.wikimedia.org/wikipedia/en/2/2f/NBA_2K25_cover_art.jpg",
        "MLB The Show 24": "https://upload.wikimedia.org/wikipedia/en/d/d8/MLB_The_Show_24_Cover.jpg",
        "Uncharted: Legacy of Thieves": "https://upload.wikimedia.org/wikipedia/en/1/1a/Uncharted_4_box_artwork.jpg",
        "The Last of Us Part I": "https://upload.wikimedia.org/wikipedia/en/8/86/The_Last_of_Us_Part_I_cover.jpg",
        "Ghost of Tsushima Director's Cut": "https://upload.wikimedia.org/wikipedia/en/b/b6/Ghost_of_Tsushima.jpg",
        "Gran Turismo 7": "https://upload.wikimedia.org/wikipedia/en/1/14/Gran_Turismo_7_cover_art.jpg",
        "Need for Speed Unbound": "https://upload.wikimedia.org/wikipedia/en/d/db/Need_for_Speed_Unbound.png",
        "WipEout Omega Collection": "https://upload.wikimedia.org/wikipedia/en/a/ae/WipeoutOmega_coverUS.jpg",
        "Astro's Playroom": "https://upload.wikimedia.org/wikipedia/en/c/c6/Astro%27s_Playroom.jpg",
        "Returnal": "https://upload.wikimedia.org/wikipedia/en/9/91/Returnal_cover_art.jpg",
    }

    games = [
        Game(
            title="Horizon Forbidden West",
            description="Explore distant lands, fight bigger and more awe-inspiring machines, and encounter new tribes as you return to the far-future, post-apocalyptic world of Horizon.",
            price=Decimal("69.99"),
            sale_price=Decimal("49.99"),
            image_url=covers["Horizon Forbidden West"],
            platform="PS5,PS4",
            category_id=categories["Action"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2022, 2, 18),
        ),
        Game(
            title="God of War Ragnarok",
            description="Join Kratos and Atreus on a mythic journey for answers before the prophesied battle that will end the world.",
            price=Decimal("69.99"),
            sale_price=Decimal("39.99"),
            image_url=covers["God of War Ragnarok"],
            platform="PS5,PS4",
            category_id=categories["Action"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2022, 11, 9),
        ),
        Game(
            title="Spider-Man 2",
            description="Spider-Men Peter Parker and Miles Morales face the ultimate test of strength inside and outside the mask against Venom and the symbiote threat.",
            price=Decimal("69.99"),
            image_url=covers["Spider-Man 2"],
            platform="PS5",
            category_id=categories["Action"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2023, 10, 20),
        ),
        Game(
            title="Final Fantasy XVI",
            description="An epic dark fantasy world where the weights of legacy and the fight for freedom collide in an action-packed adventure.",
            price=Decimal("69.99"),
            sale_price=Decimal("44.99"),
            image_url=covers["Final Fantasy XVI"],
            platform="PS5",
            category_id=categories["RPG"].id,
            publisher="Square Enix",
            release_date=date(2023, 6, 22),
        ),
        Game(
            title="Elden Ring",
            description="Rise, Tarnished, and be guided by grace to brandish the power of the Elden Ring and become an Elden Lord in the Lands Between.",
            price=Decimal("59.99"),
            sale_price=Decimal("39.99"),
            image_url=covers["Elden Ring"],
            platform="PS5,PS4",
            category_id=categories["RPG"].id,
            publisher="Bandai Namco Entertainment",
            release_date=date(2022, 2, 25),
        ),
        Game(
            title="Persona 5 Royal",
            description="Don the mask of Joker and join the Phantom Thieves of Hearts as they stage grand heists to change the hearts of corrupt adults.",
            price=Decimal("59.99"),
            image_url=covers["Persona 5 Royal"],
            platform="PS5,PS4",
            category_id=categories["RPG"].id,
            publisher="Atlus",
            release_date=date(2022, 10, 21),
        ),
        Game(
            title="EA Sports FC 25",
            description="Experience the next generation of football with HyperMotion technology and over 19,000 players across 700+ teams.",
            price=Decimal("69.99"),
            sale_price=Decimal("34.99"),
            image_url=covers["EA Sports FC 25"],
            platform="PS5,PS4",
            category_id=categories["Sports"].id,
            publisher="Electronic Arts",
            release_date=date(2024, 9, 27),
        ),
        Game(
            title="NBA 2K25",
            description="Take the court in the most authentic basketball experience with unrivaled player control and next-gen visuals.",
            price=Decimal("69.99"),
            image_url=covers["NBA 2K25"],
            platform="PS5,PS4",
            category_id=categories["Sports"].id,
            publisher="2K Sports",
            release_date=date(2024, 9, 6),
        ),
        Game(
            title="MLB The Show 24",
            description="Step up to the plate and experience the thrill of Major League Baseball with stunning fidelity and deep gameplay.",
            price=Decimal("59.99"),
            sale_price=Decimal("29.99"),
            image_url=covers["MLB The Show 24"],
            platform="PS5,PS4",
            category_id=categories["Sports"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2024, 3, 19),
        ),
        Game(
            title="Uncharted: Legacy of Thieves",
            description="Remastered collection of Uncharted 4 and The Lost Legacy, rebuilt for PS5 with enhanced visuals and DualSense features.",
            price=Decimal("49.99"),
            image_url=covers["Uncharted: Legacy of Thieves"],
            platform="PS5",
            category_id=categories["Adventure"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2022, 1, 28),
        ),
        Game(
            title="The Last of Us Part I",
            description="Experience the emotionally charged story of Joel and Ellie, rebuilt from the ground up for PS5 with modernized gameplay.",
            price=Decimal("69.99"),
            sale_price=Decimal("49.99"),
            image_url=covers["The Last of Us Part I"],
            platform="PS5",
            category_id=categories["Adventure"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2022, 9, 2),
        ),
        Game(
            title="Ghost of Tsushima Director's Cut",
            description="Forge a new path and wage an unconventional war for the freedom of Tsushima in this open-world action adventure.",
            price=Decimal("59.99"),
            sale_price=Decimal("29.99"),
            image_url=covers["Ghost of Tsushima Director's Cut"],
            platform="PS5,PS4",
            category_id=categories["Adventure"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2021, 8, 20),
        ),
        Game(
            title="Gran Turismo 7",
            description="From classic cars to supercars, experience the best that the world of motorsport has to offer in stunning 4K.",
            price=Decimal("69.99"),
            sale_price=Decimal("39.99"),
            image_url=covers["Gran Turismo 7"],
            platform="PS5,PS4",
            category_id=categories["Racing"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2022, 3, 4),
        ),
        Game(
            title="Need for Speed Unbound",
            description="Race against the clock, outrun the cops, and take on weekly qualifiers to reach the ultimate street racing challenge.",
            price=Decimal("49.99"),
            image_url=covers["Need for Speed Unbound"],
            platform="PS5",
            category_id=categories["Racing"].id,
            publisher="Electronic Arts",
            release_date=date(2022, 12, 2),
        ),
        Game(
            title="WipEout Omega Collection",
            description="Two critically acclaimed anti-gravity racing games in one blistering package, remastered and running at a silky smooth framerate.",
            price=Decimal("19.99"),
            image_url=covers["WipEout Omega Collection"],
            platform="PS4",
            category_id=categories["Racing"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2017, 6, 7),
        ),
        Game(
            title="Astro's Playroom",
            description="Explore four worlds, each based on a PS5 console component, in this charming platformer that showcases the DualSense controller.",
            price=Decimal("0.00"),
            image_url=covers["Astro's Playroom"],
            platform="PS5",
            category_id=categories["Action"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2020, 11, 12),
            is_free=True,
        ),
        Game(
            title="Returnal",
            description="Break the cycle of chaos on an ever-changing alien planet in this roguelike third-person shooter.",
            price=Decimal("69.99"),
            sale_price=Decimal("49.99"),
            image_url=covers["Returnal"],
            platform="PS5",
            category_id=categories["Action"].id,
            publisher="Sony Interactive Entertainment",
            release_date=date(2021, 4, 30),
        ),
    ]

    for game in games:
        db.add(game)

    db.flush()

    random.seed(42)
    review_ns = uuid.UUID("12345678-1234-5678-1234-567812345678")

    usernames = [
        "GamerX99",
        "PSFanatic",
        "NightOwlGamer",
        "PixelHunter",
        "ShadowBlade",
        "CyberNinja42",
        "RetroKing",
        "StarChaser",
        "ThunderGod",
        "VoidWalker",
        "DragonSlayer",
        "NeonPhoenix",
    ]

    review_texts = [
        "Absolutely incredible game! Can't stop playing.",
        "Great visuals but the story could be better.",
        "One of the best games this generation.",
        "Solid gameplay, worth every penny.",
        "A masterpiece that sets the bar high.",
        "Fun but a bit repetitive after a while.",
        "Amazing soundtrack and atmosphere.",
        "Good game, but too short for the price.",
        "Highly recommended for fans of the genre.",
        "Exceeded all my expectations!",
        "Decent game, nothing groundbreaking.",
        "The controls feel tight and responsive.",
        "Beautiful graphics, engaging story.",
        "A must-play for PlayStation owners.",
        "Pretty good, but the DLC is overpriced.",
    ]

    review_count = 0
    for game in games:
        num_reviews = random.randint(3, 6)
        chosen_users = random.sample(usernames, num_reviews)
        for uname in chosen_users:
            user_id = uuid.uuid5(review_ns, uname)
            rating = random.choices(
                [1, 2, 3, 4, 5], weights=[5, 10, 20, 35, 30], k=1
            )[0]
            text = random.choice(review_texts)
            days_ago = random.randint(1, 180)
            review = Review(
                game_id=game.id,
                user_id=user_id,
                username=uname,
                rating=rating,
                review_text=text,
                created_at=datetime.utcnow() - timedelta(days=days_ago),
            )
            db.add(review)
            review_count += 1

    db.commit()
    print(
        f"Seeded {len(categories)} categories, "
        f"{len(games)} games, and {review_count} reviews."
    )
