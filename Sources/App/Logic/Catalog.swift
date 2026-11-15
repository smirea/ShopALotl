import Foundation

/// The groceries the app knows before the owner has bought anything: which aisle each belongs to, and names for
/// autocomplete. Within an aisle the more common items come first, which is the order suggestions use.
struct Catalog: Sendable {
    struct Product: Equatable, Sendable {
        let key: NameKey
        let name: String
        let category: Category
        /// Position within its aisle: smaller is more common.
        let rank: Int
    }

    static let shared = Catalog(source: groceries)

    let products: [Product]
    private let byKey: [NameKey: Product]
    /// By `singular(key)`, so "banana" finds "Bananas" and "tomatoes" finds "Tomato".
    private let bySingular: [String: Product]

    init(source: [(Category, String)]) {
        products = source.flatMap { category, names in
            names.split(separator: ",").enumerated().compactMap { rank, name in
                let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return NameKey(name).map { Product(key: $0, name: name, category: category, rank: rank) }
            }
        }
        byKey = Dictionary(products.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        bySingular = Dictionary(products.map { (Self.singular($0.key.text), $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The product a name is, plural or not. The name as written wins, so "Mints" is the candy and "Mint" the herb.
    func product(for key: NameKey) -> Product? {
        byKey[key] ?? bySingular[Self.singular(key.text)]
    }

    /// The category of the longest run of words in the name that is a product, the run nearest the end first, since
    /// the last words usually say what a thing is: "barista oat milk" is milk's aisle, "chicken thighs" chicken's.
    /// A guess, because "peanut butter" is not butter.
    func headCategory(for key: NameKey) -> Category? {
        let words = key.words
        guard words.count > 1 else { return nil }
        for length in stride(from: words.count - 1, through: 1, by: -1) {
            for start in stride(from: words.count - length, through: 0, by: -1) {
                let run = words[start..<start + length].joined(separator: " ")
                if let product = bySingular[Self.singular(run)] { return product.category }
            }
        }
        return nil
    }

    /// The last word without its plural ending. Only used to look names up, never in a stored key.
    static func singular(_ key: String) -> String {
        guard let space = key.lastIndex(of: " ") else { return singularWord(key) }
        return key[...space] + singularWord(String(key[key.index(after: space)...]))
    }

    private static func singularWord(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return word.dropLast(3) + "y" }
        if word.count > 4, word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.count > 4, ["ses", "xes", "zes", "ches", "shes"].contains(where: word.hasSuffix) { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") { return String(word.dropLast()) }
        return word
    }

    private static let groceries: [(Category, String)] = [
        (.produce, """
            Bananas, Apples, Avocados, Tomatoes, Onions, Garlic, Lemons, Limes, Potatoes, Carrots, Cucumbers, Spinach, \
            Lettuce, Bell peppers, Broccoli, Strawberries, Blueberries, Grapes, Oranges, Mushrooms, Celery, Ginger, \
            Cilantro, Parsley, Basil, Scallions, Green onions, Red onions, Sweet potatoes, Zucchini, Cherry tomatoes, \
            Jalapeños, Kale, Arugula, Romaine, Cabbage, Cauliflower, Corn, Green beans, Asparagus, Brussels sprouts, \
            Eggplant, Squash, Butternut squash, Beets, Radishes, Leeks, Shallots, Fennel, Peas, Snap peas, Bok choy, \
            Raspberries, Blackberries, Pineapple, Mango, Watermelon, Cantaloupe, Peaches, Pears, Plums, Nectarines, \
            Cherries, Kiwi, Grapefruit, Clementines, Mandarins, Tangerines, Pomegranate, Coconut, Dates, Figs, Mint, \
            Dill, Rosemary, Thyme, Sage, Chives, Lemongrass, Chili peppers, Serrano peppers, Habaneros, Poblano peppers, \
            Salad mix, Mixed greens, Spring mix, Coleslaw mix, Sprouts, Bean sprouts, Okra, Turnips, Parsnips, Rutabaga, \
            Artichokes, Chard, Collard greens, Endive, Radicchio, Watercress, Tomatillos, Plantains, Papaya, \
            Passion fruit, Persimmons, Apricots, Cranberries, Herbs, Fruit, Vegetables, Salad, Peppers, Berries, Melon, \
            Yams, Edamame, Microgreens
            """),
        (.bakery, """
            Bread, Bagels, Tortillas, Baguette, Sourdough, Buns, Hamburger buns, Hot dog buns, Rolls, Croissants, \
            English muffins, Pita, Naan, Muffins, Donuts, Cake, Cupcakes, Pie, Cookies, Brownies, Whole wheat bread, \
            White bread, Rye bread, Ciabatta, Focaccia, Brioche, Flatbread, Wraps, Corn tortillas, Flour tortillas, \
            Pizza dough, Pastries, Danish, Scones, Banana bread, Cornbread, Dinner rolls, Breadsticks, Pretzel buns, \
            Challah, Lavash
            """),
        (.deli, """
            Ham, Sliced turkey, Salami, Prosciutto, Roast beef, Pastrami, Hummus, Rotisserie chicken, Deli meat, Lunch meat, \
            Pepperoni, Mortadella, Chorizo, Olives, Pickles, Guacamole, Salsa, Potato salad, Coleslaw, Pasta salad, \
            Sushi, Sandwiches, Fresh pasta, Fresh mozzarella, Burrata, Brie, Feta, Goat cheese, Blue cheese, Gouda, \
            Gruyère, Manchego, Tzatziki, Pesto, Tapenade, Smoked salmon, Lox, Pâté, Quiche, Soup, Tofu, Tempeh, \
            Seitan, Kimchi, Sauerkraut
            """),
        (.meat, """
            Chicken, Chicken breast, Chicken thighs, Ground beef, Turkey, Bacon, Sausage, Steak, Pork chops, Ground turkey, \
            Chicken wings, Chicken drumsticks, Whole chicken, Beef, Pork, Lamb, Ribs, Pork tenderloin, Pork shoulder, \
            Brisket, Ribeye, Sirloin, Filet mignon, Flank steak, Skirt steak, Short ribs, Stew meat, Meatballs, \
            Hot dogs, Bratwurst, Italian sausage, Breakfast sausage, Ground pork, Ground chicken, Ground lamb, \
            Lamb chops, Veal, Duck, Turkey breast, Burgers, Burger patties, Chuck roast, Pork belly, Ham hock, \
            Chicken tenders, Carnitas
            """),
        (.seafood, """
            Salmon, Shrimp, Tuna, Cod, Tilapia, Scallops, Crab, Lobster, Mussels, Clams, Oysters, Halibut, Sea bass, \
            Trout, Mahi mahi, Swordfish, Sardines, Anchovies, Calamari, Squid, Octopus, Catfish, Snapper, Haddock, \
            Fish, Fish fillets, Prawns, Crab cakes, Tuna steak, Salmon fillets
            """),
        (.dairy, """
            Milk, Eggs, Butter, Cheese, Yogurt, Greek yogurt, Cream cheese, Sour cream, Heavy cream, Half and half, \
            Cheddar, Mozzarella, Parmesan, Shredded cheese, Sliced cheese, Cottage cheese, Oat milk, Almond milk, \
            Soy milk, Coconut milk beverage, Whipping cream, Whipped cream, Creamer, Coffee creamer, Buttermilk, \
            Ricotta, Swiss cheese, Provolone, Monterey jack, Pepper jack, American cheese, String cheese, Kefir, \
            Skyr, Egg whites, Margarine, Ghee, Crème fraîche, Mascarpone, Queso fresco, Cotija, Halloumi, Paneer, \
            Whole milk, Skim milk, Lactose free milk, Chocolate milk, Eggnog, Custard, Pudding, Cream
            """),
        (.frozen, """
            Ice cream, Frozen pizza, Frozen vegetables, Frozen fruit, Frozen berries, Ice, Frozen peas, Frozen corn, \
            Frozen spinach, Frozen broccoli, French fries, Tater tots, Hash browns, Frozen waffles, Frozen burritos, \
            Frozen dumplings, Dumplings, Potstickers, Gyoza, Chicken nuggets, Fish sticks, Frozen meals, \
            Frozen shrimp, Popsicles, Sorbet, Gelato, Frozen yogurt, Ice cream bars, Frozen pie, Pie crust, \
            Puff pastry, Frozen lasagna, Pizza rolls, Veggie burgers, Frozen edamame, Frozen mango, Frozen strawberries
            """),
        (.pantry, """
            Rice, Pasta, Olive oil, Flour, Sugar, Salt, Black pepper, Canned tomatoes, Tomato sauce, Pasta sauce, \
            Chicken broth, Beans, Black beans, Chickpeas, Peanut butter, Honey, Soy sauce, Vinegar, Ketchup, Mustard, \
            Mayonnaise, Hot sauce, Spaghetti, Penne, Macaroni, Noodles, Ramen, Rice noodles, Quinoa, Couscous, Lentils, \
            Kidney beans, Pinto beans, White beans, Refried beans, Canned tuna, Canned corn, Canned beans, \
            Tomato paste, Diced tomatoes, Crushed tomatoes, Marinara, Alfredo sauce, Vegetable broth, Beef broth, \
            Stock, Bouillon, Coconut milk, Vegetable oil, Canola oil, Avocado oil, Sesame oil, Coconut oil, \
            Cooking spray, Balsamic vinegar, Apple cider vinegar, Rice vinegar, White vinegar, Red wine vinegar, \
            Brown sugar, Powdered sugar, Baking soda, Baking powder, Yeast, Cornstarch, Vanilla extract, Vanilla, \
            Cocoa powder, Chocolate chips, Maple syrup, Jam, Jelly, Nutella, Almond butter, Tahini, Sriracha, \
            BBQ sauce, Worcestershire sauce, Fish sauce, Oyster sauce, Hoisin sauce, Teriyaki sauce, Salad dressing, \
            Ranch, Relish, Capers, Sun dried tomatoes, Artichoke hearts, Roasted red peppers, Breadcrumbs, Panko, \
            Croutons, Taco shells, Taco seasoning, Cumin, Paprika, Smoked paprika, Chili powder, \
            Cinnamon, Oregano, Garlic powder, Onion powder, Red pepper flakes, Cayenne, Turmeric, Curry powder, \
            Curry paste, Nutmeg, Bay leaves, Italian seasoning, Coriander, Cardamom, Cloves, Sesame seeds, Spices, \
            Seasoning, Sea salt, Kosher salt, Peppercorns, Almonds, Walnuts, Pecans, Cashews, Peanuts, Pine nuts, \
            Pistachios, Raisins, Dried cranberries, Dried fruit, Chia seeds, Flax seeds, Sunflower seeds, \
            Pumpkin seeds, Canned soup, Mac and cheese, Instant noodles, Rice cakes, Polenta, Cornmeal, \
            Oil, Sauce, Molasses, Agave, Sweetener, Stevia, Gelatin, Sprinkles, Food coloring, Evaporated milk, \
            Condensed milk, Pumpkin puree, Applesauce, Canned fruit, Pickled jalapeños, Miso, Nori, \
            Seaweed, Wasabi, Mirin, Gochujang, Harissa, Enchilada sauce, Green chiles, \
            Bread flour, Whole wheat flour, Almond flour, Basmati rice, Jasmine rice, Brown rice, Arborio rice, \
            Orzo, Lasagna noodles, Egg noodles, Udon, Soba, Farro, Barley, Bulgur, Split peas
            """),
        (.breakfast, """
            Cereal, Oatmeal, Oats, Granola, Pancake mix, Syrup, Waffles, Granola bars, Protein bars, Pop tarts, \
            Muesli, Rolled oats, Steel cut oats, Instant oatmeal, Breakfast bars, Cream of wheat, Grits, \
            Toaster pastries, Cereal bars
            """),
        (.snacks, """
            Chips, Crackers, Popcorn, Pretzels, Chocolate, Candy, Tortilla chips, Potato chips, Nuts, Trail mix, \
            Gum, Mints, Gummy bears, Fruit snacks, Beef jerky, Jerky, Pita chips, Cheese puffs, Goldfish, \
            Graham crackers, Oreos, Dark chocolate, Chocolate bars, Marshmallows, Rice crispy treats, Seaweed snacks, \
            Mixed nuts, Dried mango, Energy bars, Snack bars, Pudding cups, Jello, Fruit cups, Applesauce pouches, \
            Veggie straws, Kettle chips, Corn chips, Doritos, Cheetos, Pringles, Peanut butter cups, Lollipops, \
            Licorice, Caramels, Wafers, Biscuits, Shortbread, Animal crackers, Cheese crackers, Snacks
            """),
        (.beverages, """
            Coffee, Water, Sparkling water, Orange juice, Tea, Juice, Soda, Apple juice, Coke, Diet coke, Sprite, \
            Lemonade, Iced tea, Kombucha, Energy drinks, Sports drinks, Gatorade, Coconut water, Tonic water, \
            Club soda, Seltzer, Ginger ale, Ginger beer, Root beer, Coffee beans, Ground coffee, Espresso, \
            Coffee pods, K cups, Cold brew, Green tea, Black tea, Herbal tea, Chai, Matcha, Hot chocolate, Cocoa mix, \
            Protein shakes, Smoothies, Cranberry juice, Grape juice, Tomato juice, Vegetable juice, Lime juice, \
            Lemon juice, Bottled water, Mineral water, La croix, Drink mix, Electrolytes, Pepsi, Dr pepper, \
            Mountain dew, Fanta, Red bull, Almond creamer
            """),
        (.alcohol, """
            Beer, Wine, Red wine, White wine, Rosé, Champagne, Prosecco, Vodka, Whiskey, Bourbon, Tequila, Rum, Gin, \
            Hard seltzer, Cider, Hard cider, Sake, Vermouth, Mezcal, Scotch, Brandy, Cognac, Liqueur, Bitters, IPA, \
            Lager, Stout, Sparkling wine, Aperol, Campari, Triple sec, Baileys
            """),
        (.household, """
            Paper towels, Toilet paper, Trash bags, Dish soap, Laundry detergent, Sponges, Aluminum foil, \
            Plastic wrap, Ziploc bags, Napkins, Tissues, Dishwasher detergent, Dishwasher pods, Laundry pods, \
            Fabric softener, Dryer sheets, Bleach, All purpose cleaner, Glass cleaner, Disinfecting wipes, \
            Cleaning wipes, Hand soap, Parchment paper, Wax paper, Sandwich bags, Freezer bags, Garbage bags, \
            Compost bags, Light bulbs, Batteries, Candles, Matches, Lighter, Air freshener, Toilet cleaner, \
            Stain remover, Paper plates, Plastic cups, Paper cups, Plastic utensils, Straws, Coffee filters, \
            Scrub brush, Rubber gloves, Mop, Broom, Vacuum bags, Furniture polish, Drain cleaner, Bug spray, \
            Ant traps, Mouse traps, Charcoal, Lighter fluid, Foil, Cling film, Tape, Glue, Printer paper, Pens, \
            Storage bags, Food containers, Toothpicks, Skewers, Twine, Detergent, Cleaner, Wipes, Soap
            """),
        (.personalCare, """
            Toothpaste, Shampoo, Conditioner, Deodorant, Body wash, Bar soap, Razors, Shaving cream, Floss, \
            Mouthwash, Toothbrush, Lotion, Sunscreen, Lip balm, Cotton swabs, Q tips, Cotton balls, Tampons, Pads, \
            Band aids, Bandages, Ibuprofen, Advil, Tylenol, Acetaminophen, Aspirin, Vitamins, Multivitamins, \
            Vitamin C, Vitamin D, Allergy medicine, Cold medicine, Cough drops, Antacids, Hand sanitizer, Face wash, \
            Moisturizer, Makeup remover, Nail polish remover, Hair gel, Hair spray, Contact solution, Eye drops, \
            Condoms, Melatonin, Probiotics, Fish oil, Protein powder, Hand cream, Face masks, Body lotion, \
            Bath bombs, Hair ties, Bobby pins, Dental floss, Tweezers, Nail clippers, Thermometer, First aid kit, \
            Medicine, Pain reliever
            """),
        (.baby, """
            Diapers, Baby wipes, Formula, Baby food, Baby formula, Pull ups, Diaper cream, Baby shampoo, Baby lotion, \
            Baby cereal, Pacifiers, Baby bottles, Baby snacks, Teething biscuits, Baby wash, Nursing pads, \
            Training pants, Sippy cups
            """),
        (.pet, """
            Dog food, Cat food, Cat litter, Dog treats, Cat treats, Poop bags, Pet food, Dog bones, Flea treatment, \
            Bird seed, Fish food, Litter, Wet cat food, Dry cat food, Wet dog food, Dry dog food, Dog shampoo, \
            Chew toys, Catnip, Puppy pads
            """),
    ]
}
