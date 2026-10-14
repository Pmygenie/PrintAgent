# Bill round-off

This document describes how bill round-off works in this branch, and how to implement the same behavior on another branch.

Round-off adjusts only the printed bill total to a whole rupee. The adjustment is printed as its own line. Item prices, tax, discount, tip, and the rest of the breakdown are left as the server sent them.

The rule is not standard half-rupee rounding. Ten paise is enough to round the total up.

## Switch

Rounding is controlled by the restaurant profile field `total_round`.

| Source | Field | Default |
|---|---|---|
| API restaurant object | `total_round` | `"No"` |
| Cached profile JSON | `totalRound` | `"No"` |
| In-memory model | `RestaurantProfileModel.totalRound` | `"No"` |

It is on only when the value, after `trim()` and `toLowerCase()`, is exactly `yes`. `Yes`, `YES`, and ` yes ` all count as on. Anything else, including a missing field, is off.

When it is off:

- The printed total is the raw amount, including paise.
- The round-off amount is `0`.
- No Round Off line is printed.

Profile wiring lives in `lib/core/profile/restaurant_profile_model.dart`:

- Constructor default: `this.totalRound = 'No'`
- `fromApi`: `restaurant['total_round']?.toString() ?? 'No'`
- `fromJson`: `json['totalRound']?.toString() ?? 'No'`
- `toJson`: `'totalRound': totalRound`

## Which amount is rounded

Only one figure is rounded. Which bill field it comes from depends on the order type.

A bill is a room order when `bill['associated_orders']` is a non-empty list (`ReceiptBusinessLogic.isRoomOrder`).

| Bill | Raw total field |
|---|---|
| Room order | `payment_amount` |
| Every other bill, including aggregator | `grant_amount` |

Missing or non-numeric values parse as `0.0` via `double.tryParse`.

These lines are never passed through the round-off function:

- Item Total (`order_item_total`)
- Service Charge, Delivery Charge, Packing Charge
- Discount, Coupon, Loyalty, Wallet
- Tip
- Sub Total (`order_subtotal`)
- GST / CGST / SGST / VAT
- Room Advance, Room Pending
- Each previous room order amount (`order_amount`)

Aggregator bills (`is_aggregator == true`) still use this round-off on `grant_amount`. Aggregator only changes tax labeling and skips the UPI QR. It does not disable rounding.

## The calculation

All of the logic is in `lib/core/printer/bitmap/receipt_business_logic.dart`. The printers do not reimplement it. They call these helpers.

```dart
static double billAmount(Map<String, dynamic> bill, String key) =>
    double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

static int getRoundUpValue(double value, {double threshold = 0.10}) {
  final decimal =
      double.parse((value - value.floor()).toStringAsFixed(2));
  return decimal >= threshold ? value.ceil() : value.floor();
}

static bool isTotalRoundEnabled(RestaurantProfileModel profile) =>
    profile.totalRound.trim().toLowerCase() == 'yes';

static double rawBillTotal(Map<String, dynamic> bill) {
  final grantAmount = billAmount(bill, 'grant_amount');
  final paymentAmount = billAmount(bill, 'payment_amount');
  return isRoomOrder(bill) ? paymentAmount : grantAmount;
}

static double printedBillTotal(
  Map<String, dynamic> bill,
  RestaurantProfileModel profile,
) {
  final raw = rawBillTotal(bill);
  if (!isTotalRoundEnabled(profile)) return raw;
  return getRoundUpValue(raw).toDouble();
}

static double roundOffAmount(
  Map<String, dynamic> bill,
  RestaurantProfileModel profile,
) {
  if (!isTotalRoundEnabled(profile)) return 0;
  return printedBillTotal(bill, profile) - rawBillTotal(bill);
}
```

### Paise decision

`getRoundUpValue` looks at the fractional part with a threshold of `0.10`. The threshold argument exists, but every caller uses the default. Do not change it to `0.50` unless the product rule changes.

1. Fractional part = `value - value.floor()`.
2. Format that fraction with `toStringAsFixed(2)` and parse it back to a double. This removes floating-point noise such as `0.099999999999` vs `0.10`.
3. If the two-decimal fraction is greater than or equal to `0.10`, return `value.ceil()` (next whole rupee).
4. If it is less than `0.10`, return `value.floor()` (current whole rupee).

`0.10` rounds up. `0.09` rounds down.

### Three values

| Name | Meaning |
|---|---|
| `rawBillTotal` | Unrounded `payment_amount` or `grant_amount` |
| `printedBillTotal` | Whole rupees when rounding is on; otherwise the raw amount |
| `roundOffAmount` | `printedBillTotal - rawBillTotal` |

Sign:

- Positive round-off means the customer pays more than the raw total.
- Negative round-off means the customer pays less.
- Zero means the raw total was already a whole rupee, or rounding is off.

When rounding is on, `printedBillTotal` is always a whole number (`int` converted with `.toDouble()`).

### Worked examples

Rounding on:

| Raw total | Paise after 2 decimals | Printed total | Round off | Round Off line |
|---|---|---|---|---|
| 250.00 | 0.00 | 250 | 0.00 | hidden |
| 250.01 | 0.01 | 250 | -0.01 | shown |
| 250.09 | 0.09 | 250 | -0.09 | shown |
| 250.10 | 0.10 | 251 | +0.90 | shown |
| 250.50 | 0.50 | 251 | +0.50 | shown |
| 250.99 | 0.99 | 251 | +0.01 | shown |
| 100.00 | 0.00 | 100 | 0.00 | hidden |

Rounding off: printed total stays `250.50`, round-off is `0`, and the Round Off line is hidden.

## What is printed

ESC/POS, PDF, and bitmap bills all do the same thing, in this order, after VAT and before the total divider:

1. `totalAmount = ReceiptBusinessLogic.printedBillTotal(bill, profile)`
2. `roundOff = ReceiptBusinessLogic.roundOffAmount(bill, profile)`
3. If `roundOff.abs() >= 0.005`, print a line labeled `Round Off`.
4. Print `TOTAL` from `totalAmount`.

The `0.005` check hides an exact zero and any float dust smaller than half a paisa. A real one-paisa adjustment (`0.01` or `-0.01`) is shown, because `0.01 >= 0.005`.

### Two different number formats

Round Off and TOTAL are formatted differently.

Round Off always uses `toStringAsFixed(2)`:

- `0.90` prints as `0.90`
- `-0.09` prints as `-0.09`
- `0.50` prints as `0.50`

TOTAL uses `formatMoney` (named `_formatMoney` inside the ESC/POS and PDF formatters, and `ReceiptBusinessLogic.formatMoney` in the bitmap renderer):

```dart
static String formatMoney(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
```

So a rounded total prints as `251`, not `251.00`. If rounding is off and the raw total is `250.50`, TOTAL prints as `250.5`.

`formatMoney` is display only. It is not the round-off rule. Do not use it to compute the adjustment.

### Call sites

| Output | File | Round Off line | TOTAL |
|---|---|---|---|
| ESC/POS thermal | `lib/core/printer/escpos_formatter.dart` | `_alignRightLabelValue('Round Off', roundOff.toStringAsFixed(2))` | `_formatMoney(totalAmount)` |
| PDF bill | `lib/core/printer/pdf_formatter.dart` | `_billAmountLineWidgets('Round Off', roundOff.toStringAsFixed(2))` | `_formatMoney(totalAmount)` |
| Bitmap bill | `lib/core/printer/bitmap/bill_renderer.dart` | `drawLabelValue('Round Off', roundOff.toStringAsFixed(2), ...)` | `ReceiptBusinessLogic.formatMoney(totalAmount)` |

Receipt order in all three:

1. Item Total and the other breakdown lines (unrounded, two decimals where they already use `toStringAsFixed(2)`).
2. Round Off, only when `abs >= 0.005`.
3. Divider.
4. TOTAL, using the printed (possibly rounded) total.

The Round Off line uses the same amount-line style as Sub Total and tax (`billAmountLine`). TOTAL uses the total style (`billTotal`).

## UPI QR amount

When dynamic UPI is on, the QR amount must match the printed TOTAL, not the raw `grant_amount`.

`PrintConfig.upiQrDataForBill` (`lib/core/config/print_config.dart`):

```dart
static String upiQrDataForBill(
  Map<String, dynamic> bill, {
  double? amountOverride,
}) {
  double d(String key) =>
      double.tryParse(bill[key]?.toString() ?? '0') ?? 0.0;

  final grantAmount = d('grant_amount');
  final totalAmount = amountOverride ?? grantAmount;

  final amount = upiDynamicEnabled ? totalAmount.toStringAsFixed(2) : '0';
  return 'upi://pay?pa=$upiId&pn=&am=$amount&tn=';
}
```

ESC/POS and PDF pass the override:

```dart
PrintConfig.upiQrDataForBill(
  bill,
  amountOverride: ReceiptBusinessLogic.printedBillTotal(bill, profile),
)
```

Consequences:

- Rounding on, dynamic UPI on: `am` is the whole-rupee printed total, still written with two decimals (`251.00`).
- Rounding off: `am` is the raw printed total (`payment_amount` for a room bill, `grant_amount` otherwise).
- Dynamic UPI off (`upiDynamicEnabled == false`): `am` is always `0`, even if an override was passed. The QR is static.
- Aggregator bills never get a UPI QR (`!isAggregator` is required before the QR is built).
- The bitmap renderer does not draw a UPI QR.

Without `amountOverride`, the helper falls back to `grant_amount` only. A room bill would then QR the wrong field. Callers that show a payable total must pass `printedBillTotal`.

## Room GRAND TOTAL is a separate figure

Room bills print two totals:

1. The main TOTAL, near the tax block. This one uses `printedBillTotal`, so it is `payment_amount` and it is rounded when `total_round` is `yes`. The Round Off line belongs to this total.
2. A later GRAND TOTAL inside the previous-room section. This one prints raw `grant_amount` with `toStringAsFixed(0)`, prefixed with `Rs.`.

`toStringAsFixed(0)` is ordinary display rounding of `grant_amount`. It does not use the `0.10` threshold, and it does not print a Round Off line. Room Advance, Room Pending, and each associated `order_amount` stay unrounded (two decimals).

Do not replace GRAND TOTAL with `printedBillTotal` unless that is an intentional product change. Today they are different numbers on purpose: TOTAL is what is payable now (`payment_amount`, optionally rounded); GRAND TOTAL is the room `grant_amount` shown as a rupee string.

## A4 bills do not use this round-off

`lib/core/printer/a4_bill_formatter.dart` does not call `printedBillTotal` or `roundOffAmount`.

- Its TOTAL is the raw `payment_amount` for a room order, otherwise raw `grant_amount`.
- It has no Round Off line.
- Its "In Words" line uses that same raw total.
- Its UPI QR calls `upiQrDataForBill(bill)` with no `amountOverride`, so dynamic UPI uses raw `grant_amount` and ignores both room `payment_amount` and round-off.

Porting round-off to A4 means using the same helpers, not copying the current A4 total code.

## How to implement this on another branch

1. Keep the profile flag. Load `restaurant['total_round']` into `totalRound`, default `"No"`, and persist it as `totalRound` in cached JSON.
2. Put the math in one place: `isTotalRoundEnabled`, `rawBillTotal`, `getRoundUpValue`, `printedBillTotal`, `roundOffAmount`. Do not duplicate the `0.10` check inside each formatter.
3. Treat a room order as `associated_orders` being a non-empty list. Round `payment_amount` for those bills and `grant_amount` for every other bill.
4. On every bill layout that should match thermal/PDF/bitmap:
   - Print Round Off only when `roundOff.abs() >= 0.005`, with `toStringAsFixed(2)`, before the total divider.
   - Print TOTAL from `printedBillTotal`, through `formatMoney` (whole rupees drop the decimals).
5. Pass `printedBillTotal` as `amountOverride` into `upiQrDataForBill` wherever a dynamic UPI QR is built for that bill.
6. Leave the breakdown lines, room advance, room pending, associated order amounts, and the room GRAND TOTAL (`grant_amount` via `toStringAsFixed(0)`) unchanged.
7. Leave rounding off when `total_round` is anything other than `yes`.

### Checks after porting

Rounding on:

- `250.09` prints Round Off `-0.09` and TOTAL `250`.
- `250.10` prints Round Off `0.90` and TOTAL `251`.
- `250.00` prints no Round Off line and TOTAL `250`.
- A room bill rounds `payment_amount`, not `grant_amount`.
- Dynamic UPI `am` equals the printed TOTAL (`251.00` for a `250.10` bill).
- Aggregator bills still round the total and still do not print a UPI QR.

Rounding off:

- No Round Off line.
- TOTAL keeps paise (`250.5` for `250.50` via `formatMoney`).
- Dynamic UPI uses that same unrounded payable amount.
