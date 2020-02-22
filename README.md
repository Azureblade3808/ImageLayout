# ImageLayout

## Motivation

I had been working on an iOS app which let customers create photo books with their own photos.

At first, preset image layouts were provided for the customers to play with. The image slots in the layouts were mostly having a fixed aspect ratio of 2:3 or 3:2, according to traditional photos. But soon after, we realized that mobile photos were not the case because they tended to have different and variable aspect ratios. So, a photo selected from a customer's phone would nearly never fit in a preset image slot perfectly, which means that photos would probably get cropped. And what was worse, app users seemed far less willing to check the contents they created, possibly because they were not professional designers and it was difficult to do such checkings on a phone. As a result, it happened time to time that some important part of a photo, such as a human head or some text, got cut off. We needed to repair such photos by manual re-editting, or just reject the order. It became quite a burden both mentally and physically, as the number of app users grew.

What if there could be some layouts having every image slot perfectly match photos in aspect ratios, which meant no more cutting-offs, and thus no more manual work or order rejections? They needed not to be too ugly though, or they would not be used. An algorithm which could generate such layouts sounded like a good idea.

## Main Thought

TODO
