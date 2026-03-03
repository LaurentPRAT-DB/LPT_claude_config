# Uber Receipt Download

## Overview
Download Uber ride receipts for expense reporting. Receipts can be downloaded as PDFs or forwarded via email.

## Authentication
- URL: https://riders.uber.com/trips
- Login options: **Phone/Email recommended** (Google SSO may not work)
- Will require 2FA via SMS code

## Navigation Steps

### 1. Access Trip History
```
https://riders.uber.com/trips
```

After login, you'll see:
- **Upcoming** section (scheduled rides)
- **Past** section with trips listed by date range
- Filters: Personal/Business, All Trips

Each trip shows:
- Destination address
- Date and time
- Trip cost
- Quick actions: Help, Details, Rebook

### 2. Find Trips in Date Range
- Past trips are grouped by date range (e.g., "Sep 10 - Dec 3")
- Scroll through trips to find those after the expense cutoff date
- Click "More" at bottom to load older trips

### 3. Open Trip Details
For each trip to expense:
1. Click **"Details"** link on the trip card
2. This opens the trip detail page showing:
   - Trip date/time and driver name
   - Route map
   - Amount and payment method
   - **"View Receipt"** and **"Resend Receipt"** buttons

### 4. Download Receipt PDF
1. Click **"View Receipt"** button
2. A receipt dialog opens showing full breakdown:
   - Total amount
   - Trip fare + fees breakdown
   - Payment method and date
   - Trip details (vehicle type, distance, duration)
   - Pickup/dropoff addresses
3. Click **"Download PDF"** button at bottom of dialog
4. PDF downloads to your default downloads folder

Alternative: Click **"Resend by Email"** to email receipt to registered email.

### 5. Receipt PDF URL Pattern
Direct PDF download URL format:
```
https://riders.uber.com/trips/{trip-id}/receipt?contentType=PDF&timestamp={timestamp}
```

## Receipt Details
Uber receipts typically include:
- Trip date and time
- Pickup and dropoff addresses
- Distance traveled
- Fare breakdown (base fare, time, distance, fees, tip)
- Total amount
- Payment method (last 4 digits)
- Trip ID

## Expense Category
**Taxi / RideShare** - Use this category in Emburse

## Tips
- Receipts are available for 90 days (may vary)
- Business trips may be tagged in the app
- Consider setting up Uber for Business for automatic receipt forwarding

## Email Upload to Emburse
After downloading, email receipts to: `receipt@ca1.chromeriver.com`
- Subject: Amount (e.g., "34.41 USD")
- Attach the PDF receipt
- OCR will extract details automatically

## Screenshot Fallback
If PDF download is unavailable:
1. Navigate to trip details
2. Take screenshot of receipt view
3. Save as PNG/JPG (min 50KB)
4. Email to Emburse receipt address

## Common Issues
- **Login loop**: Clear cookies and try again
- **Missing trips**: Check date range, some trips may be under Uber Eats
- **Receipt not loading**: Try refreshing or accessing from different browser
