# ImageLayout

## Motivation

I had been working on an iOS app which let customers create photo books with their own photos.

At first, preset image layouts were provided for the customers to play with. The image slots in the layouts were mostly having a fixed aspect ratio of 2:3 or 3:2, according to traditional photos. But soon after, we realized that mobile photos were not the case because they tended to have different and variable aspect ratios. So, a photo selected from a customer's phone would nearly never fit in a preset image slot perfectly, which means that photos would probably get cropped. And what was worse, app users seemed far less willing to check the contents they created, possibly because they were not professional designers and it was difficult to do such checkings on a phone. As a result, it happened time to time that some important part of a photo, such as a human head or some text, got cut off. We needed to repair such photos by manual re-editting, or just reject the order. It became quite a burden both mentally and physically, as the number of app users grew.

What if there could be some layouts having every image slot perfectly match photos in aspect ratios, which meant no more cutting-offs, and thus no more manual work or order rejections? They needed not to be too ugly though, or they would not be used. An algorithm which could generate such layouts sounded like a good idea.

## Main Thought

At this time, there is only one kind of layout, aka AlignedImageLayout. Here is how it has been developed.

We can agree that an auto-generated layout will have quite a number of constraints, which the calculation will be based on. The constraints that we have thought about are:
1. An image slot must have the same aspect ratio of a corresponding image, which is the core concept why we are here.
1. Every side of every image must either align to one side of the container or one side of another image, which will make the whole layout something like a grid and not too ugly.
1. The container must be covered with no white space at the borders, because if there is white space, it can be cropped out logically.
1. There may be white space with a unified size between adjacent images and the space should be easily adjusted, which is also for beauty reason.

We can imagine such a layout may look like:
```
*-----*-------*-------*
|     |   1   |       |
|     *-------*   3   |
|  0  |       |       |
|     |   2   *-------|
|     |       |   4   |
*-----*-------*-------*
```
with some white space at the internal seams.

Let's assume the size of the container satisfies:
```
w = A * h + B
h = C * w + D
```
while `w` is the width, `h` is the height and `A`, `B`, `C`, `D` are some constants that we should figure out. And it's not difficult to tell that if `A` and `B` are found, so are `C` and `D`, and vice versa.

As for the slot 1, we can see:
```
w_1 = A_1 * h_1 + 0
h_1 = C_1 * w_1 + 0
```
As the slot has the same aspect ratio of its corresponding image, `A_1` and `C_1` should be obtained when the image is given.

The same goes for slot 2：
```
w_2 = A_2 * h_2 + 0
h_2 = C_2 * w_2 + 0
```

Then considering the combination of slot 1 and slot 2, we can come to:
```
w_1_2 = A_1_2 * h_1_2 + B_1_2
h_1_2 = C_1_2 * w_1_2 + D_1_2
```
It can be noticed that `w_1_2` equals both `w_1` and `w_2`, so there is:
```
h_1_2 = (C_1 + C_2) * w_1_2 + s_v
```
where `s_v` is the vertical space between image slots. So `C_1_2` equals `C_1 + C_2` and `D_1_2` equals `s_v`. And if we inverse the formula, we can also find `A_1_2` and `B_1_2`.

Similar processes goes on towards the full layout, and we will finally find what `A`, `B`, `C`, `D` are. Since then, as the size of the container has been given, we will find all sizes of each slot.

Now, we will find all possible layouts, if we are able to find all possible slicing methods.

__TO BE CONTINUED__
