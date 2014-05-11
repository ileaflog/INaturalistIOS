INaturalistIOS
==============

INaturalistIOS is the official iOS app for submitting data to [iNaturalist.org](http://www.inaturalist.org).

Setup
-----
We're using a number of submodules so there's a little more to do than cloning:

    git clone git@github.com:inaturalist/INaturalistIOS.git
    cd INaturalistIOS/
    cp config.h.example config.h # and edit to configure for your project
    git submodule init
    git submodule update
    cd Vendor/Facebook && ./scripts/build_framework.sh

That should get you set up for local development with the Simulator. If you want to test on actual devices you'll need to get a provisioning profile from Apple and configure the project to use it: https://developer.apple.com/ios/manage/overview/index.action.
