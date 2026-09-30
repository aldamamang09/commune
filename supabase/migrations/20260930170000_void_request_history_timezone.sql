-- Flutter previously stored local DateTime ISO values without a timezone.
-- PostgreSQL interpreted them as UTC; recover the original instant from the
-- millisecond epoch embedded in Flutter-generated request IDs.
update public.void_requests
set requested_at = to_timestamp(
  substring(id from '^void-request-([0-9]{13})$')::double precision / 1000
)
where id ~ '^void-request-[0-9]{13}$';
