// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Device builds: no helper processes, so keep networking and compositing in-process too.
pref("network.process.enabled", false);
pref("layers.gpu-process.enabled", false);
pref("fission.autostart", false);
