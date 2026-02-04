//// The Swift Programming Language
//// https://docs.swift.org/swift-book

// The Onslow Swedish Kumara Stall :P
// A cli program for a roadside kumara stall.
//
// The owner can add stock, check how much kumara is left, review past sales,
// and see summary statistics. Customers can record a sale by entering the
// weight of kumara and the number of bags they used.
//
// Prices and limits:
// - Kumara: $3.00 per kilogram
// - Bags: $0.20 each
// - Bin capacity: 50 kg
// - Minimum sale: 0.1 kg (one kumara)
// - Maximum weight per bag: 5 kg
// - Maximum bags per sale: 5,000

import Foundation

// MARK: - Constants

/// The price charged for each kilogram of kumara.
let kumaraPricePerKilogram = 3.0

/// The price charged for each bag.
let bagPrice = 0.20

/// The most kumara the container can hold, in kilograms.
let maximumStockKilograms = 50.0

/// The greatest weight that a single bag can hold, in kilograms.
let maximumBagCapacityKilograms = 5.0

/// The smallest sale allowed, in kilograms (100 grams, or one kumara).
let minimumSaleWeightKilograms = 0.1

/// The greatest number of bags one sale may use.
let maximumBagsPerSale = 5_000

// MARK: - Errors

/// Reasons why stock cannot be added to the container.
enum StockError: Error, Equatable {
    /// The amount was zero or negative.
    case notPositive

    /// The addition would make the container hold more than 50 kg.
    case exceedsCapacity(spaceRemaining: Double)

    /// A message that can be shown to the user.
    var message: String {
        switch self {
        case .notPositive:
            return "Stock must be greater than 0 kg."
        case .exceedsCapacity(let spaceRemaining):
            return
                "That is too much stock. The container only has \(formatKilograms(spaceRemaining)) kg of space left."
        }
    }
}

/// Reasons why a sale cannot be recorded.
enum SaleError: Error, Equatable {
    /// The weight was below the 0.1 kg minimum.
    case weightTooSmall

    /// The weight was greater than the kumara currently in the container.
    case weightExceedsStock(available: Double)

    /// The bag count was zero, negative, or above the 5,000 bag limit.
    case invalidBagCount

    /// The bags provided cannot hold the weight because each bag holds at most 5 kg.
    case notEnoughBags(requiredBags: Int)

    /// A message that can be shown to the user.
    var message: String {
        switch self {
        case .weightTooSmall:
            return
                "The smallest sale is \(formatKilograms(minimumSaleWeightKilograms)) kg (one kumara)."
        case .weightExceedsStock(let available):
            return
                "That is more kumara than the stall has. Only \(formatKilograms(available)) kg remains in stock."
        case .invalidBagCount:
            return "The number of bags must be between 1 and \(maximumBagsPerSale)."
        case .notEnoughBags(let requiredBags):
            return
                "Those bags are not big enough. This sale needs at least \(requiredBags) bags (5 kg maximum per bag)."
        }
    }
}

// MARK: - Data models

/// The prices calculated for one sale before it is saved.
struct SaleQuote {
    /// The charge for the kumara itself.
    let kumaraCharge: Double

    /// The charge for the bags used.
    let bagCharge: Double

    /// The kumara charge plus the bag charge.
    let totalCharge: Double
}

/// One completed sale, stored so that the owner can review it later.
struct Sale {
    /// The sale's position in the list, starting at 1.
    let number: Int

    /// The weight of kumara sold, in kilograms.
    let weightKilograms: Double

    /// The number of bags the customer used.
    let bags: Int

    /// The charge for the kumara.
    let kumaraCharge: Double

    /// The charge for the bags.
    let bagCharge: Double

    /// The total amount the customer paid.
    var totalCharge: Double {
        kumaraCharge + bagCharge
    }
}

/// Totals and averages calculated from every sale so far.
struct StallSummary {
    let saleCount: Int
    let totalWeightKilograms: Double
    let totalBags: Int
    let totalEarned: Double

    /// The owner's target figure: total kumara sold divided by total bags used.
    var averageWeightPerBag: Double {
        guard totalBags > 0 else { return 0 }
        return totalWeightKilograms / Double(totalBags)
    }

    /// The average amount earned for each bag used.
    var averageEarnedPerBag: Double {
        guard totalBags > 0 else { return 0 }
        return totalEarned / Double(totalBags)
    }
}

//! MARK: - Formatting helpers

///! Rounds a money value to whole cents so that totals do not gain tiny
///! floating-point errors when they are added together.
///
///? Parameters:
///? - value: the amount of money to round.
///? Returns: the amount rounded to two decimal places.
func roundedToCents(_ value: Double) -> Double {
    return (value * 100).rounded() / 100
}

/// Formats a weight in kilograms without unnecessary trailing zeros.
///
/// For example, 2.500 becomes "2.5" and 50.000 becomes "50".
///
/// Parameters:
/// - kilograms: the weight to format.
/// Returns: the weight as a neat text string.
func formatKilograms(_ kilograms: Double) -> String {
    var text = String(format: "%.3f", kilograms)

    // Remove zeroes after the decimal point, then remove a leftover point.
    while text.hasSuffix("0") {
        text.removeLast()
    }
    if text.hasSuffix(".") {
        text.removeLast()
    }

    return text
}

/// Formats money as a dollar amount with two decimal places.
///
/// Parameters:
/// - amount: the amount of money to format.
/// Returns: the amount as text, for example "$7.90".
func formatMoney(_ amount: Double) -> String {
    return String(format: "$%.2f", amount)
}

// MARK: - Input helpers

/// Shows a prompt and reads one line of text from the user.
///
/// Whitespace around the user's answer is removed. Returning nil means the
/// input has ended, which lets the program close cleanly when it is piped
/// input from a file or when the user presses Ctrl+D / Ctrl+Z.
///
/// Parameters:
/// - prompt: the question to show the user.
/// Returns: the cleaned input, or nil if there is no more input.
func readInput(_ prompt: String) -> String? {
    print(prompt, terminator: "")
    guard let line = readLine() else {
        print()
        return nil
    }
    return line.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Asks the user for a decimal number.
///
/// Parameters:
/// - prompt: the question to show the user.
/// Returns: the number entered, or nil if the input was cancelled or was not
///   a valid number.
func readDouble(_ prompt: String) -> Double? {
    guard let text = readInput(prompt) else { return nil }
    guard let value = Double(text) else {
        print("Please enter a valid number.")
        return nil
    }
    return value
}

/// Asks the user for a whole number.
///
/// Parameters:
/// - prompt: the question to show the user.
/// Returns: the number entered, or nil if the input was cancelled or was not
///   a valid whole number.
func readInteger(_ prompt: String) -> Int? {
    guard let text = readInput(prompt) else { return nil }
    guard let value = Int(text) else {
        print("Please enter a whole number.")
        return nil
    }
    return value
}

// MARK: - Validation and calculation

/// Checks whether an amount of stock can be added to the container.
///
/// Parameters:
/// - amount: the number of kilograms the owner wants to add.
/// - currentStock: the number of kilograms already in the container.
/// Returns: the reason the addition is invalid, or nil if it is allowed.
func validateStockAddition(amount: Double, currentStock: Double) -> StockError? {
    guard amount > 0 else {
        return .notPositive
    }

    let spaceRemaining = maximumStockKilograms - currentStock

    // The small tolerance prevents 0.1 + 0.2 style rounding errors from
    // rejecting an addition that should exactly fill the container.
    guard amount <= spaceRemaining + 0.000_001 else {
        return .exceedsCapacity(spaceRemaining: max(0, spaceRemaining))
    }

    return nil
}

/// Calculates and validates the charges for a proposed sale.
///
/// This function does not change the stock; it only works out whether the
/// sale is allowed and what it would cost.
///
/// Parameters:
/// - weightKilograms: the total weight of kumara the customer is buying.
/// - bags: the number of bags the customer used.
/// - availableStock: the number of kilograms currently in the container.
/// Returns: a successful quote, or the reason the sale is invalid.
func quoteSale(weightKilograms: Double, bags: Int, availableStock: Double) -> Result<
    SaleQuote, SaleError
> {
    // A kumara weighs about 100 g, so 0.1 kg is the smallest fair sale.
    guard weightKilograms >= minimumSaleWeightKilograms else {
        return .failure(.weightTooSmall)
    }

    // Never sell more kumara than the container holds.
    guard weightKilograms <= availableStock + 0.000_001 else {
        return .failure(.weightExceedsStock(available: availableStock))
    }

    guard bags >= 1, bags <= maximumBagsPerSale else {
        return .failure(.invalidBagCount)
    }

    // Work out how many bags are needed if each bag is filled to 5 kg.
    let requiredBags = Int(ceil(weightKilograms / maximumBagCapacityKilograms))
    guard bags >= requiredBags else {
        return .failure(.notEnoughBags(requiredBags: requiredBags))
    }

    let kumaraCharge = roundedToCents(weightKilograms * kumaraPricePerKilogram)
    let bagCharge = roundedToCents(Double(bags) * bagPrice)
    let totalCharge = roundedToCents(kumaraCharge + bagCharge)

    return .success(
        SaleQuote(
            kumaraCharge: kumaraCharge,
            bagCharge: bagCharge,
            totalCharge: totalCharge
        ))
}

// MARK: - Stall

/// Holds the stall's stock and sales, and provides the actions the owner and
/// customers need. Marking the methods `mutating` allows them to change the
/// stock and the sales collection.
struct KumaraStall {
    /// The kumara currently in the container, in kilograms.
    private(set) var stockKilograms = 0.0

    /// Every completed sale, newest last.
    private(set) var sales: [Sale] = []

    /// Adds kumara to the container.
    ///
    /// Parameters:
    /// - amount: the number of kilograms to add.
    /// Returns: the reason the addition failed, or nil if it succeeded.
    mutating func addStock(_ amount: Double) -> StockError? {
        if let error = validateStockAddition(amount: amount, currentStock: stockKilograms) {
            return error
        }

        stockKilograms += amount

        // Protect against tiny floating-point overshoots at the 50 kg limit.
        stockKilograms = min(stockKilograms, maximumStockKilograms)
        return nil
    }

    /// Validates and records a sale, then removes the sold kumara from stock.
    ///
    /// Parameters:
    /// - weightKilograms: the total weight of kumara sold.
    /// - bags: the number of bags used.
    /// Returns: the saved sale, or the reason the sale was rejected.
    mutating func recordSale(weightKilograms: Double, bags: Int) -> Result<Sale, SaleError> {
        let result = quoteSale(
            weightKilograms: weightKilograms,
            bags: bags,
            availableStock: stockKilograms
        )

        switch result {
        case .failure(let error):
            return .failure(error)

        case .success(let quote):
            // A sale is only saved after every check has passed, so invalid
            // sales never reduce the stock or appear in the records.
            stockKilograms -= weightKilograms
            if stockKilograms < 0 {
                stockKilograms = 0
            }

            let sale = Sale(
                number: sales.count + 1,
                weightKilograms: weightKilograms,
                bags: bags,
                kumaraCharge: quote.kumaraCharge,
                bagCharge: quote.bagCharge
            )
            sales.append(sale)
            return .success(sale)
        }
    }

    /// Builds the totals and averages shown to the owner.
    ///
    /// Returns: a summary of every recorded sale.
    func makeSummary() -> StallSummary {
        let totalWeight = sales.reduce(0) { $0 + $1.weightKilograms }
        let totalBags = sales.reduce(0) { $0 + $1.bags }
        let totalEarned = sales.reduce(0) { $0 + $1.totalCharge }

        return StallSummary(
            saleCount: sales.count,
            totalWeightKilograms: totalWeight,
            totalBags: totalBags,
            totalEarned: roundedToCents(totalEarned)
        )
    }
}

// MARK: - Menu actions

/// Asks the customer for a weight and bag count, then records the sale.
///
/// Parameters:
/// - stall: the stall whose stock and sales will be updated.
func recordSaleFlow(stall: inout KumaraStall) {
    print("\n--- NEW SALE ---")

    guard let weight = readDouble("Weight of kumara (kg): ") else { return }
    guard let bags = readInteger("Number of bags used: ") else { return }

    switch stall.recordSale(weightKilograms: weight, bags: bags) {
    case .failure(let error):
        print("Sale rejected: \(error.message)")

    case .success(let sale):
        print("\nSale #\(sale.number) recorded.")
        print("  Weight:        \(formatKilograms(sale.weightKilograms)) kg")
        print("  Bags:          \(sale.bags)")
        print("  Kumara charge: \(formatMoney(sale.kumaraCharge))")
        print("  Bag charge:    \(formatMoney(sale.bagCharge))")
        print("  TOTAL:         \(formatMoney(sale.totalCharge))")
        print("Stock remaining: \(formatKilograms(stall.stockKilograms)) kg")
    }
}

/// Asks the owner how much stock to add and updates the container.
///
/// Parameters:
/// - stall: the stall whose stock will be updated.
func addStockFlow(stall: inout KumaraStall) {
    print("\n--- ADD STOCK ---")
    print("Container space: \(formatKilograms(maximumStockKilograms - stall.stockKilograms)) kg")

    guard let amount = readDouble("Amount to add (kg): ") else { return }

    if let error = stall.addStock(amount) {
        print("Stock not added: \(error.message)")
    } else {
        print("Added \(formatKilograms(amount)) kg.")
        print(
            "Current stock: \(formatKilograms(stall.stockKilograms)) kg of \(formatKilograms(maximumStockKilograms)) kg"
        )
    }
}

/// Displays how much kumara is left in the container.
///
/// Parameters:
/// - stall: the stall whose stock will be displayed.
func viewStock(stall: KumaraStall) {
    print("\n--- CURRENT STOCK ---")
    print("Kumara remaining: \(formatKilograms(stall.stockKilograms)) kg")
    print("Space remaining:  \(formatKilograms(maximumStockKilograms - stall.stockKilograms)) kg")

    if stall.stockKilograms == 0 {
        print("The container is empty.")
    } else if stall.stockKilograms < 5 {
        print("Stock is running low.")
    }
}

/// Displays every sale, oldest first.
///
/// Parameters:
/// - stall: the stall whose sales will be displayed.
func viewSales(stall: KumaraStall) {
    print("\n--- PREVIOUS SALES ---")

    guard !stall.sales.isEmpty else {
        print("No sales have been recorded yet.")
        return
    }

    for sale in stall.sales {
        print(
            "#\(sale.number) | \(formatKilograms(sale.weightKilograms)) kg | \(sale.bags) bag(s) | "
                + "Kumara \(formatMoney(sale.kumaraCharge)) | Bags \(formatMoney(sale.bagCharge)) | "
                + "Total \(formatMoney(sale.totalCharge))")
    }
}

/// Displays the owner's summary, including the averages used to plan pre-bagged sales.
///
/// Parameters:
/// - stall: the stall whose sales will be summarised.
func viewSummary(stall: KumaraStall) {
    print("\n--- OWNER SUMMARY ---")

    let summary = stall.makeSummary()

    guard summary.saleCount > 0 else {
        print("No sales have been recorded yet, so there is no average to show.")
        return
    }

    print("Sales recorded:          \(summary.saleCount)")
    print("Kumara sold:             \(formatKilograms(summary.totalWeightKilograms)) kg")
    print("Bags used:               \(summary.totalBags)")
    print("Total earned:            \(formatMoney(summary.totalEarned))")
    print("Average weight per bag:  \(String(format: "%.3f", summary.averageWeightPerBag)) kg")
    print("Average earned per bag:  \(formatMoney(summary.averageEarnedPerBag))")
}

/// Prints the main menu.
func printMenu() {
    print(
        """

        ==============================
                KUMARA STALL
        ==============================
        1. Record a sale (customer)
        2. Add stock (owner)
        3. View current stock
        4. View previous sales
        5. View owner summary
        6. Quit
        """)
}

// MARK: - Program entry point

@main
struct SwiftPlayground {
    static func main() {
        var stall = KumaraStall()
        var isRunning = true

        print("Welcome to the roadside kumara stall!")

        while isRunning {
            printMenu()

            print("\n")
            guard let choice = readInput("Choose an option (1-6): ") else {
                // No more input: close the program without crashing.
                print("\nGoodbye!")
                break
            }

            switch choice {
            case "1":
                recordSaleFlow(stall: &stall)
            case "2":
                addStockFlow(stall: &stall)
            case "3":
                viewStock(stall: stall)
            case "4":
                viewSales(stall: stall)
            case "5":
                viewSummary(stall: stall)
            case "6":
                print("\nGoodbye!")
                isRunning = false
            default:
                print("Invalid option. Please choose a number from 1 to 6.")
            }
        }
    }
}
