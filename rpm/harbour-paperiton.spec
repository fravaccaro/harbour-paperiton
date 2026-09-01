Name:       harbour-paperiton

Summary:    Paperless-ngx client for Sailfish OS
Version:    0.5
Release:    1
License:    GPLv3
URL:        https://github.com/fravaccaro/harbour-paperiton
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   sailfish-components-webview-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(sailfishsecrets)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils
BuildRequires:  cmake

%description
Paperiton works with the documents of a Paperless-ngx server: full text search,
filtering by tag and correspondent, thumbnails, OCR text and previews, uploads
from the device or the camera, metadata editing, notes and the task queue.
A running Paperless-ngx instance is required.

%if 0%{?_chum}
Title: Paperiton
Type: desktop-application
DeveloperName: fravaccaro
Categories:
 - Office
 - Network
Custom:
  Repo: https://github.com/fravaccaro/harbour-paperiton
PackageIcon: https://raw.githubusercontent.com/fravaccaro/harbour-paperiton/main/icons/172x172/harbour-paperiton.png
Links:
  Homepage: https://github.com/fravaccaro/harbour-paperiton
  Bugtracker: https://github.com/fravaccaro/harbour-paperiton/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build
%cmake
%make_build

%install
%make_install

desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
