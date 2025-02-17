//
// Copyright (c) WhatsApp Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit

extension CGSize {

    public static func ==(left: CGSize, right: CGSize) -> Bool {
        return left.width.isEqual(to: right.width) && left.height.isEqual(to: right.height)
    }

    public static func <(left: CGSize, right: CGSize) -> Bool {
        return left.width.isLess(than: right.width) && left.height.isLess(than: right.height)
    }

    public static func >(left: CGSize, right: CGSize) -> Bool {
        return !left.width.isLessThanOrEqualTo(right.width) && !left.height.isLessThanOrEqualTo(right.height)
    }

    public static func <=(left: CGSize, right: CGSize) -> Bool {
        return left.width.isLessThanOrEqualTo(right.width) && left.height.isLessThanOrEqualTo(right.height)
    }

    public static func >=(left: CGSize, right: CGSize) -> Bool {
        return !left.width.isLess(than: right.width) && !left.height.isLess(than: right.height)
    }

}

/**
 *  Represents the two supported extensions for sticker images: png and webp.
 */
enum ImageDataExtension: String {
    case png = "png"
    case webp = "webp"
}

/**
 *  Stores sticker image data along with its supported extension.
 */
class ImageData {
    let data: Data
    let type: ImageDataExtension

    var bytesSize: Int64 {
        return Int64(data.count)
    }

    /**
     *  Returns whether or not the data represents an animated image.
     *  It will always return false if the image is png.
     */
    lazy var animated: Bool = {
        if type == .webp {
            return WebPManager.shared.isAnimated(webPData: data)
        } else {
            return false
        }
    }()

    /**
     *  Returns the minimum frame duration for an animated image in milliseconds.
     *  It will always return -1 if the image is not animated.
     */
    lazy var minFrameDuration: Double = {
        return WebPManager.shared.minFrameDuration(webPData: data) * 1000
    }()

    /**
     *  Returns the total animation duration for an animated image in milliseconds.
     *  It will always return -1 if the image is not animated.
     */
    lazy var totalAnimationDuration: Double = {
        return WebPManager.shared.totalAnimationDuration(webPData: data) * 1000
    }()

    /**
     *  Returns the webp data representation of the current image. If the current image is already webp,
     *  the data is simply returned. If it's png, it will returned the webp converted equivalent data.
     */
    lazy var webpData: Data? = {
        if type == .webp {
            return data
        } else {
            return WebPManager.shared.encode(pngData: data)
        }
    }()

    /**
     *  Returns a UIImage of the current image data. If data is corrupt, nil will be returned.
     */
    lazy var image: UIImage? = {
        if type == .webp {
            guard let images = WebPManager.shared.decode(webPData: data) else {
                return nil
            }
            if images.count == 0 {
                return nil
            }
            if images.count == 1 {
                return images.first
            }
            return UIImage.animatedImage(with: images, duration: WebPManager.shared.totalAnimationDuration(webPData: data))
        } else {
            // Static image
            return UIImage(data: data)
        }
    }()

    /**
     * Returns an image with the new size.
     */
    func image(withSize size: CGSize) -> UIImage? {
        guard let image = image else { return nil }

        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }

    init(data: Data, type: ImageDataExtension) {
        self.data = data
        self.type = type
    }

    static func imageDataIfCompliant(contentsOfFile filename: String, isTray: Bool) throws -> ImageData {
//        let fileExtension: String = (filename as NSString).pathExtension
//
//        guard let imageURL = Bundle.main.url(forResource: filename, withExtension: "") else {
//            throw StickerPackError.fileNotFound
//        }
//
//        let data = try Data(contentsOf: imageURL)
//        guard let imageType = ImageDataExtension(rawValue: fileExtension) else {
//            throw StickerPackError.unsupportedImageFormat(fileExtension)
//        }
//
//        return try ImageData.imageDataIfCompliant(rawData: data, extensionType: imageType, isTray: isTray)
        
        
        if filename.contains("http") {
            let fileExtension: String = (filename as NSString).pathExtension

//            guard let imageURL = Bundle.main.url(forResource: filename, withExtension: "") else {
//                throw StickerPackError.fileNotFound
//            }
            
            let forecastURL1 = NSURL(string: filename)
            
            let data = try Data(contentsOf: forecastURL1! as URL)
            guard let imageType = ImageDataExtension(rawValue: fileExtension) else {
                throw StickerPackError.unsupportedImageFormat(fileExtension)
            }
            
            return try ImageData.imageDataIfCompliant(rawData: data, extensionType: imageType, isTray: isTray)
        } else {
            let fileExtension: String = (filename as NSString).pathExtension
            
            guard let imageURL = Bundle.main.url(forResource: filename, withExtension: "") else {
                throw StickerPackError.fileNotFound
            }
            
            let data = try Data(contentsOf: imageURL)
            guard let imageType = ImageDataExtension(rawValue: fileExtension) else {
                throw StickerPackError.unsupportedImageFormat(fileExtension)
            }
            
            return try ImageData.imageDataIfCompliant(rawData: data, extensionType: imageType, isTray: isTray)
        }
        
    }

    static func imageDataIfCompliant(rawData: Data, extensionType: ImageDataExtension, isTray: Bool) throws -> ImageData {
        let imageData = ImageData(data: rawData, type: extensionType)

        guard imageData.bytesSize > 0 else {
            throw StickerPackError.invalidImage
        }
        if isTray {
            guard !imageData.animated else {
                throw StickerPackError.animatedImagesNotSupported
            }

            guard imageData.bytesSize <= Limits.MaxTrayImageFileSize else {
                throw StickerPackError.imageTooBig(imageData.bytesSize, false)
            }

            guard imageData.image!.size == Limits.TrayImageDimensions else {
                throw StickerPackError.incorrectImageSize(imageData.image!.size)
            }
        } else {
            let isAnimated = imageData.animated
            guard (isAnimated && imageData.bytesSize <= Limits.MaxAnimatedStickerFileSize) ||
                    (!isAnimated && imageData.bytesSize <= Limits.MaxStaticStickerFileSize) else {
                throw StickerPackError.imageTooBig(imageData.bytesSize, isAnimated)
            }

            guard imageData.image!.size == Limits.ImageDimensions else {
                throw StickerPackError.incorrectImageSize(imageData.image!.size)
            }

            if isAnimated {
                guard imageData.minFrameDuration >= Double(Limits.MinAnimatedStickerFrameDurationMS) else {
                    throw StickerPackError.minFrameDurationTooShort(imageData.minFrameDuration)
                }

                guard imageData.totalAnimationDuration <= Double(Limits.MaxAnimatedStickerTotalDurationMS) else {
                    throw StickerPackError.totalAnimationDurationTooLong(imageData.totalAnimationDuration)
                }
            }
        }

        return imageData
    }
}
