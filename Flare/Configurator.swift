//
//  Configurator.swift
//  Flare
//
//  Created by Chris on 9/4/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

enum Configurator {
    static func go() throws {
        print("Bucket:")
        print("  If you need to, create a Backblaze B2 bucket here:")
        print("  https://secure.backblaze.com/b2_buckets.htm")
        print("  Ensure that the bucket is set to 'private'.")
        print("  In the bucket's lifecycle settings, set it to 'keep prior versions for 10 days'.")
        print("")
        print("Keys:")
        print("  You will need keys for your bucket here:")
        print("  https://secure.backblaze.com/app_keys.htm")
        print("  Select 'add a new application key'")
        print("  For the key name, enter whatever you like.")
        print("  For 'allow access to buckets', select the correct bucket.")
        print("  For 'type of access', select read and write.")
        print("  Leave the name prefix and duration blank.")
        print("  Copy the 'application key' when it is created, because Backblaze won't give it to you again.")
        print("")
        
        print("Please enter your Flare folder, eg '~/Flare`:")
        guard let folder = readLine(strippingNewline: true) else { return }
        
        print("Please enter your Backblaze Account ID, which is also referred to as the 'keyID' in the Backblaze 'App Keys' interface. Note that this is *not* the 'Master Application Key', it is the 'Application Key' you created, further down that page:")
        guard let accountId = readLine(strippingNewline: true) else { return }
        
        print("Please enter your 'Application Key' which was given to you when you created the new application key:")
        guard let applicationKey = readLine(strippingNewline: true) else { return }
        
        print("Please enter your 'Bucket Name' which is referred to as 'bucketName' in Backblaze's 'App Keys' page:")
        guard let bucketName = readLine(strippingNewline: true) else { return }

        print("Please enter your 'Bucket ID' which can be found in Backblaze's 'Buckets' page:")
        guard let bucketId = readLine(strippingNewline: true) else { return }

        let config = SyncConfig(accountId: accountId, applicationKey: applicationKey, bucketId: bucketId, bucketName: bucketName, folder: folder.withoutTrailingSlash)
        try config.save()
        print("Config saved.")
    }
}
