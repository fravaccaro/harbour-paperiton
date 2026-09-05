#ifndef PAPERLESS_FILETYPES_H
#define PAPERLESS_FILETYPES_H

#include <QMimeDatabase>
#include <QMimeType>
#include <QString>
#include <QStringList>

// Paperless puts PDFs and the image formats below through OCR and takes plain
// text as it is. Office documents and mail need Tika and Gotenberg alongside
// the server, which cannot be asked for over the API, so they are left out: a
// file the server refuses is better not offered at all. The share method in
// harbour-paperiton.desktop names the same kinds, for the apps that look before
// this one is running.
inline QStringList paperlessAcceptedMimeTypes()
{
    return QStringList()
            << QStringLiteral("application/pdf")
            << QStringLiteral("image/png")
            << QStringLiteral("image/jpeg")
            << QStringLiteral("image/tiff")
            << QStringLiteral("image/gif")
            << QStringLiteral("image/webp")
            << QStringLiteral("text/plain");
}

// The same kinds of file as patterns, since a picker can only filter on names.
// Written out rather than read off the mime database, which on one device
// answers with extensions no scanner or camera ever produces and on another
// with none at all.
inline QStringList paperlessAcceptedNameFilters()
{
    return QStringList()
            << QStringLiteral("*.pdf")
            << QStringLiteral("*.png")
            << QStringLiteral("*.jpg")
            << QStringLiteral("*.jpeg")
            << QStringLiteral("*.tif")
            << QStringLiteral("*.tiff")
            << QStringLiteral("*.gif")
            << QStringLiteral("*.webp")
            << QStringLiteral("*.txt");
}

// Whether the server would take this file. The content decides, as it does on
// the server: a file arriving from another app can be named anything, and one
// named .txt holding a picture is a picture. The kind has to be one of those
// above and not merely a kind of it, since a parser on the server is chosen by
// the name of the type: a Markdown file is text but is not plain text.
inline bool paperlessAcceptsFile(const QString &filePath)
{
    const QMimeType type = QMimeDatabase().mimeTypeForFile(filePath);
    return paperlessAcceptedMimeTypes().contains(type.name());
}

#endif // PAPERLESS_FILETYPES_H
