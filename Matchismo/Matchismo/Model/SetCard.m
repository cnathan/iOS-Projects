//
//  SetCard.m
//  Matchismo
//
//  Created by Vasco Orey on 2/14/13.
//  Copyright (c) 2013 Delta Dog Studios. All rights reserved.
//

#import "SetCard.h"

@implementation SetCard

-(BOOL)checkMatchWithFirstCard:(SetCard *)firstCard andSecondCard:(SetCard *)secondCard
{
    int total = self.asInt + firstCard.asInt + secondCard.asInt;
    NSLog(@"%d %d %d --> %d (%d, %d,%d)", self.asInt, firstCard.asInt, secondCard.asInt, total, total % self.asInt, total % firstCard.asInt, total % secondCard.asInt);
    return
    ((self.numberOfShapes == firstCard.numberOfShapes && self.numberOfShapes == secondCard.numberOfShapes) ||
     (self.numberOfShapes != firstCard.numberOfShapes && self.numberOfShapes != secondCard.numberOfShapes && firstCard.numberOfShapes != secondCard.numberOfShapes)) &&
    ((self.shade == firstCard.shade && self.shade == secondCard.shade) ||
     (self.shade != firstCard.shade && self.shade != secondCard.shade && firstCard.shade != secondCard.shade)) &&
    ((self.shape == firstCard.shape && self.shape == secondCard.shape) ||
     (!self.shape == firstCard.shape && !self.shape == secondCard.shape && !firstCard.shape == secondCard.shape)) &&
    ((self.color == firstCard.color && self.color == secondCard.color) ||
     (self.color != firstCard.color && self.color != secondCard.color && firstCard.color != secondCard.color));
}

-(int)asInt
{
    return (self.color * 1000) + (self.shape * 100) + (self.shade * 10) + self.numberOfShapes;
}

-(int)match:(NSArray *)otherCards
{
    int score = 0;
    /*
     * A Set match must satisfy all these conditions:
     *
     *  1) All cards have the same number of symbols OR 3 diferent numbers
     *  2) All cards have the same symbol OR 3 diferent symbols
     *  3) All cards have the same shading OR 3 diferent shadings
     *  4) All cards have the same color OR 3 diferent colors
     *  5) There are exactly 3 cards.
     */
    if([otherCards count] == 2 && [self checkMatchWithFirstCard:otherCards[0] andSecondCard:otherCards[1]])
    {
        NSLog(@"Match!");
        score = 1;
    }
    return score;
}

-(NSString *)description
{
    NSString *description = [NSString stringWithFormat:@"%d%d%d%d", self.shape, self.numberOfShapes, self.color, self.shade];
    return self.numberOfShapes ? description : @"?";
}

-(void)setShape:(int)shape
{
    if(shape > 0 && shape <= [SetCard numberOfShapes])
    {
        _shape = shape;
    }
}

-(void)setShade:(int)shade
{
    if(shade > 0 && shade <= [SetCard maxShade])
    {
        _shade = shade;
    }
}

-(float)shadeValue
{
    return self.shade == [SetCard maxShade] ? 1.0f : (float)(self.shade - 1) / [SetCard maxShade];
}

-(void)setColor:(int)color
{
    if(color > 0 && color <= [SetCard maxColor])
    {
        _color = color;
    }
}

-(void)setNumberOfShapes:(int)numShapes
{
    if(numShapes > 0 && numShapes <= [SetCard maxShapes])
    {
        _numberOfShapes = numShapes;
    }
}

-(NSString *)contents
{
    return [NSString stringWithFormat:@"%d %d %d %d", self.shape, self.numberOfShapes, self.color, self.shade];
}

+(int)numberOfShapes
{
    return 3;
}

+(int)maxShapes
{
    return 3;
}

+(int)maxShade
{
    return 3;
}

+(int)maxColor
{
    return 3;
}

@end
