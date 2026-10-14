/// Default for nullable `copyWith` parameters, so `copyWith(deadline: null)`
/// can clear a field while omitting it keeps the old value.
const keep = Object();

T? pick<T>(Object? value, T? current) =>
    identical(value, keep) ? current : value as T?;
