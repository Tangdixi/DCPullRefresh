# DCPullRefresh

![Gif](https://raw.githubusercontent.com/Tangdixi/DCPullRefresh/master/ScreenShot/1.gif)

I saw this amazing design from [Dribble](https://dribbble.com/shots/1797373-Pull-Down-To-Refresh). 

##Install with CocoaPods

```bash
pod 'DCPullRefresh', '~> 1.0'
``` 

##How to use

It's simple, you just need:

```Swift
tableView.dcRefreshControl = DCRefreshControl {
      
      // Updating related code here
      // ......
      
      self.tableView.reloadData()
      
    }
```

###Todo

*  More property 
*  Add UICollectionView support
*  Make animation more smooth

##Issues, Bugs, Suggestions

Open an [issue](https://github.com/Tangdixi/DCPullRefresh/issues) 

##License

**DCPullRefresh** is available under the MIT license. See the LICENSE file for more info.

