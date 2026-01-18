# Acta

A macOS app for matching invoices with bank statements. Acta streamlines accounting reconciliation by automatically linking your invoices to corresponding bank transactions.

## Overview

Acta helps you:
1. **Import invoices** (PDF or images)
2. **Import bank statements** (CSV files)
3. **Match them automatically** and verify the results

Your data syncs across devices via iCloud.

## Setup

1. **Install Acta** from the latest GitHub release
2. **Launch the app** - you'll be guided through onboarding
3. **Enter your name or company name**
   - Used to determine invoice direction (incoming vs. outgoing payments)
   - Prevents your own name from being used as a vendor name
4. **Add your OpenRouter API key**
   - Required for OCR processing to extract data from invoice documents
   - Get your API key from [openrouter.ai](https://openrouter.ai)
   - Can be added later in Settings if you skip onboarding

## Workflow

### 1. Import Invoices

Drag and drop PDF or image files into the Invoices view, or use **File > Import Invoice** (⌘I).

Supported formats: PDF, JPEG, PNG, HEIC, GIF, TIFF, BMP, WebP

The app automatically detects duplicate files to prevent re-importing the same invoice.

### 2. Process Invoices with OCR

After importing, Acta extracts invoice data using OCR (optical character recognition). The system automatically extracts:

- Vendor name
- Invoice number
- Date
- Total amount
- Pre-tax amount
- Tax percentage
- Currency
- Direction (incoming/outgoing)

Once processed, invoices move from **New** to **Processed** status.

**Note:** OCR requires an OpenRouter API key, which you can configure during onboarding or in Settings.

### 3. Verify OCR Extractions

Open **Review Invoices** (⌘⇧R) to verify OCR-extracted data:

- View the original document alongside extracted fields
- Edit any incorrectly extracted values
- Approve to mark as **OCR Verified**
- Navigate between invoices with ⌘← and ⌘→

After verification, files are automatically renamed using the vendor name and date for easy organization.

### 4. Import Bank Statements

Import your bank statements as CSV files. The import wizard helps you configure:

- **Delimiter**: Auto-detected (comma, semicolon, tab, or pipe)
- **Row selection**: Skip header/footer rows as needed
- **Column mapping**: Specify which columns contain the date, vendor, reference, amount, and currency
- **Date format**: Select the format used in your CSV
- **Decimal separator**: Choose between `.` or `,` for decimal points
- **Blacklist filters**: Exclude certain transactions (e.g., internal transfers) by keyword

A live preview shows how your data will be parsed before importing.

### 5. Automatic Matching

After importing bank statements, Acta automatically links them to invoices based on:

- **Amount**: Exact match (accounting for currency and direction)
- **Date**: Within a 7-day window

A match is only created when there's exactly one invoice that fits these criteria, avoiding ambiguous links. Matched statements move to **Linked** status.

### 6. Verify Invoice-Statement Links

Open **Review Links** (⌘⇧L) to verify automatic matches:

- View matched invoice and bank statement side-by-side
- See warnings if amounts don't match exactly
- Approve valid links or reassign to a different invoice
- Mark as **Verified** once confirmed

After approval, both the invoice and bank statement are marked as **Statement Verified** and **Verified** respectively, completing the reconciliation workflow.

## Status Meanings

Each invoice progresses through these statuses:

**Invoices:**
| Status | Meaning |
|--------|---------|
| New | Imported but not yet processed |
| Processed | OCR extraction completed |
| OCR Verified | User reviewed and approved OCR data |
| Statement Verified | Linked to a bank statement and verified |


**Bank Statements:**
| Status | Meaning |
|--------|---------|
| Unlinked | No matching invoice found |
| Linked | Automatically matched to an invoice |
| Verified | Link reviewed and approved by user |

## Tips

- **Search and filter** to quickly find specific invoices or statements.
- **Toggle Views** with ⌘1 for Invoices and ⌘2 for bank statements
- **iCloud Drive:** All imported invoices are stored in a iCloud Drive folder for automatic backup and cross-device access.

## Requirements

- macOS
- iCloud account (for document storage and sync)
- OpenRouter API key (for OCR features)
