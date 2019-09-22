//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

//import ApplicationServices
//
//var spec: VoiceSpec = VoiceSpec()
//GetIndVoice(1, &spec)
//
//var chan: SpeechChannel?
//NewSpeechChannel(&spec, &chan)
//
////kSpeechGenerateTune
////kSpeechRelativePitch
////kSpeechRelativeDuration
////kSpeechShowSyllables
//var options: CFNumber = kSpeechShowSyllables as CFNumber
////SetSpeechProperty(<#T##chan: SpeechChannel##SpeechChannel#>, <#T##property: CFString##CFString#>, <#T##object: CFTypeRef?##CFTypeRef?#>)
//SetSpeechProperty(chan!, kSpeechPhonemeOptionsProperty, options as CFTypeRef)
//
////https://developer.apple.com/documentation/applicationservices/kspeechphonemeoptionsproperty?language=objc
////The value associated with this property is a pointer to an CFNumber object containing the flags (options) you would pass to soPhonemeOptions. (See Phoneme Generation Options for a complete list of options.)
//
//var phonemes: CFString?
//CopyPhonemesFromText(chan!, "Monster" as CFString, &phonemes)
//
//print("Phonemes: >\(phonemes!)<")

//var done = false



let bucketId = "967fa9f24082154465d30c12"
print("Hello, World!")

// Keyid: 0006f92025453c20000000003
// applicationKey: K000HPqtBGfUkrjhbxvQFXKevD/jkNA
AuthorizeAccount.send(accountId: "0006f92025453c20000000003", applicationKey: "K000HPqtBGfUkrjhbxvQFXKevD/jkNA", completion: { result in
    switch result {
    case .success(let response):
        print(response.authorizationToken)
        HideFile.send(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: bucketId, fileName: "Icon120.png", completion: { result in
            switch result {
            case .success:
                print("Hidden :)")
                // NOTE! ListFileVersions returns two records for Icon120.png
                // First record is action:hide
                // Second is action:upload
                // Hide record uploadTimestamp": 1568850170000 IS THE TIME OF DELETION WOO HOO
                
                ListFileVersions.send(token: response.authorizationToken,
                                      apiUrl: response.apiUrl,
                                      bucketId: bucketId,
                                      startFileName: nil,
                                      startFileId: nil,
                                      prefix: nil, completion: { result in
                                        switch result {
                                        case .success(let files):
                                            print(files)
                                            exit(EXIT_SUCCESS)
                                            
                                        case .failure(let error):
                                            print(error)
                                            exit(EXIT_FAILURE)
                                        }
                })
                
            case .failure(let error):
                print(error)
                exit(EXIT_FAILURE)
            }
        })
        
    case .failure(let error):
        print(error)
        exit(EXIT_FAILURE)
    }
})


RunLoop.main.run()
//https://alejandromp.com/blog/2019/01/19/a-runloop-for-your-swift-script/
//while (!done) {
//    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
//}
//print("Done")
