# Givents Firestore Data Model

Firestore collection names and fields use `snake_case`. Timestamp fields use Firestore `Timestamp`; `TIME` fields use `HH:mm` strings.

## users

- Document ID: Firebase Auth UID.
- `uid` string (must equal the document ID)
- `email` string
- `full_name` string
- `contact_number` string
- `role` string: `organizer`, `vendor`, `attendee`
- `account_status` string: `active`, `disabled`
- `registration_id` string, optional for organizer and vendor
- `created_at` timestamp

`password_hash` is intentionally omitted; passwords are stored by Firebase Authentication.

## public_profiles

- Document ID: Firebase Auth UID.
- `uid` string
- `display_name` string
- `masked_contact` string
- `photo_url` string, optional
- `updated_at` timestamp

## organizer_profiles

- Document ID: Firebase Auth UID.
- `organizer_profile_id` string
- `organization_name` string
- `organizer_type` string
- `short_bio` string
- `area` string
- `contact_person` string
- `email` string
- `phone_number` string
- `logo_photo` string, optional
- `organizer_address` string
- `created_at` timestamp
- `updated_at` timestamp

## vendor_profiles

- Document ID: Firebase Auth UID.
- `vendor_profile_id` string
- `business_name` string
- `owner_name` string
- `product_category` string
- `product_description` string
- `registration_id` string
- `masked_contact` string
- `verification_status` string: `pending`, `verified`, `not_verified`
- `profile_photo` string, optional
- `created_at` timestamp
- `updated_at` timestamp

## vendor_documents

Unused deny-all collection. Fields: `document_id`, `vendor_profile_id`, `document_type`, `document_url`, `uploaded_at`, `verification_status`.

## events

- Document ID: auto-generated.
- `event_id` string
- `organizer_profile_id` string
- `event_title` string
- `event_category` string
- `event_description` string
- `event_date` timestamp
- `start_time` string
- `end_time` string
- `venue_name` string
- `venue_address` string
- `city` string
- `province` string
- `latitude` number, optional
- `longitude` number, optional
- `total_slots` number
- `booth_fee` number
- `event_photo` string, optional
- `event_status` string: `draft`, `published`
- `created_at` timestamp
- `published_at` timestamp, optional

## event_intake_drafts

- Document ID: auto-generated.
- `draft_id` string
- `organizer_profile_id` string
- `source_type` string: `mock`
- `raw_source_text` string
- `parsed_title` string
- `parsed_date` timestamp
- `parsed_location` string
- `parsed_category` string
- `draft_status` string: `draft`, `confirmed`, `discarded`
- `confirmed_event_id` string, optional
- `created_at` timestamp
- `updated_at` timestamp

## booth_slots

- Document ID: `{event_id}_{slot_code}`.
- `slot_id` string
- `event_id` string
- `slot_code` string
- `slot_status` string: `open`, `reserved`
- `reserved_application_id` string, optional
- `reserved_at` timestamp, optional

## applications

- Document ID: `{event_id}_{vendor_profile_id}`.
- `application_id` string
- `event_id` string
- `vendor_profile_id` string
- `vendor_name` string
- `products_to_sell` string
- `booth_fee_amount` number
- `requested_slot_id` string
- `application_status` string: `pending`, `approved`, `rejected`
- `rejection_reason` string, optional
- `applied_at` timestamp
- `reviewed_at` timestamp, optional

## payments

- Document ID: `idempotency_key`.
- `payment_id` string
- `application_id` string
- `event_id` string
- `vendor_profile_id` string
- `amount` number
- `idempotency_key` string
- `payment_method` string: `gcash`
- `payment_status` string: `pending`, `paid`, `failed`
- `created_at` timestamp
- `paid_at` timestamp, optional
- `payment_reference` string, optional
- `receipt_number` string, optional

## notifications

- Document ID: auto-generated.
- `notification_id` string
- `recipient_user_id` string
- `related_event_id` string, optional
- `related_application_id` string, optional
- `notification_type` string
- `title` string
- `message` string
- `is_read` boolean
- `read_at` timestamp, optional
- `created_at` timestamp

## password_reset_requests

Unused deny-all collection. Firebase Authentication owns password reset flow.

## lost_found_reports

- Document ID: `report_code`.
- `report_id` string
- `report_code` string
- `reporter_user_id` string
- `event_id` string, optional
- `item_name` string
- `category` string
- `description` string
- `photo_url` string, optional
- `location_found` string
- `reported_at` timestamp
- `report_type` string: `lost`, `found`
- `report_status` string: `open`, `matched`, `returned`

## lost_found_claims

- Document ID: `{report_id}_{claimant_user_id}`.
- `claim_id` string
- `report_id` string
- `claimant_user_id` string
- `claim_status` string: `pending`, `approved`, `rejected`
- `ownership_details` string
- `claim_description` string
- `claimed_at` timestamp
- `resolved_at` timestamp, optional
