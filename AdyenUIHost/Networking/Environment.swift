//
// Copyright (c) 2019 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Foundation

internal enum DemoServerEnvironment {
    
    case beta, test
    
    internal var url: URL {
        switch self {
        case .beta:
            return URL(string: "https://checkout-beta.adyen.com/checkout/v53")!
        case .test:
            return URL(string: "https://checkout-test.adyen.com/v53")!
        }
    }
}
