#ifndef PAPERLESS_STALENESS_H
#define PAPERLESS_STALENESS_H

#include <QDateTime>

// The models keep what they fetched for as long as the app runs, so a page that
// shows one again asks first whether the copy has aged past what the user would
// accept. Data that was never loaded counts as stale.
inline bool paperlessIsStale(const QDateTime &loadedAt, int seconds)
{
    return !loadedAt.isValid() || loadedAt.secsTo(QDateTime::currentDateTimeUtc()) >= seconds;
}

#endif // PAPERLESS_STALENESS_H
