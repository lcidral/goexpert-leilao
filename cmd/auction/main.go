package main

import (
	"context"
	"fullcycle-auction_go/configuration/database/mongodb"
	"fullcycle-auction_go/configuration/logger"
	"fullcycle-auction_go/internal/infra/api/web/controller/auction_controller"
	"fullcycle-auction_go/internal/infra/api/web/controller/bid_controller"
	"fullcycle-auction_go/internal/infra/api/web/controller/user_controller"
	"fullcycle-auction_go/internal/infra/database/auction"
	"fullcycle-auction_go/internal/infra/database/bid"
	"fullcycle-auction_go/internal/infra/database/user"
	"fullcycle-auction_go/internal/usecase/auction_usecase"
	"fullcycle-auction_go/internal/usecase/bid_usecase"
	"fullcycle-auction_go/internal/usecase/user_usecase"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"log"
	"os"
	"strconv"
	"time"
)

func main() {
	ctx := context.Background()

	if err := godotenv.Load("cmd/auction/.env"); err != nil {
		log.Fatal("Error trying to load env variables")
		return
	}

	// Load env with defaults
	defaultDurationSec := getEnvInt("AUCTION_DEFAULT_DURATION_SEC", 300)
	scanIntervalMs := getEnvInt("AUCTION_CLOSE_SCAN_INTERVAL_MS", 1000)
	if defaultDurationSec <= 0 {
		logger.Info("Invalid AUCTION_DEFAULT_DURATION_SEC, using default 300s")
		defaultDurationSec = 300
	}
	if scanIntervalMs <= 0 {
		logger.Info("Invalid AUCTION_CLOSE_SCAN_INTERVAL_MS, using default 1000ms")
		scanIntervalMs = 1000
	}
	defaultDuration := time.Duration(defaultDurationSec) * time.Second
	scanInterval := time.Duration(scanIntervalMs) * time.Millisecond

	databaseConnection, err := mongodb.NewMongoDBConnection(ctx)
	if err != nil {
		log.Fatal(err.Error())
		return
	}

	router := gin.Default()

	userController, bidController, auctionsController, auctionRepository := initDependencies(databaseConnection, defaultDuration)

	// Start background worker for auto-close
	go startAutoCloseWorker(ctx, auctionRepository, scanInterval)

	router.GET("/auction", auctionsController.FindAuctions)
	router.GET("/auction/:auctionId", auctionsController.FindAuctionById)
	router.POST("/auction", auctionsController.CreateAuction)
	router.GET("/auction/winner/:auctionId", auctionsController.FindWinningBidByAuctionId)
	router.POST("/bid", bidController.CreateBid)
	router.GET("/bid/:auctionId", bidController.FindBidByAuctionId)
	router.GET("/user/:userId", userController.FindUserById)

	router.Run(":8080")
}

func initDependencies(database *mongo.Database, defaultDuration time.Duration) (
	userController *user_controller.UserController,
	bidController *bid_controller.BidController,
	auctionController *auction_controller.AuctionController,
	auctionRepository *auction.AuctionRepository) {

	auctionRepository = auction.NewAuctionRepository(database, defaultDuration)
	bidRepository := bid.NewBidRepository(database, auctionRepository)
	userRepository := user.NewUserRepository(database)

	userController = user_controller.NewUserController(
		user_usecase.NewUserUseCase(userRepository))
	auctionController = auction_controller.NewAuctionController(
		auction_usecase.NewAuctionUseCase(auctionRepository, bidRepository))
	bidController = bid_controller.NewBidController(bid_usecase.NewBidUseCase(bidRepository))

	return
}

func getEnvInt(key string, def int) int {
	val := os.Getenv(key)
	if val == "" {
		return def
	}
	i, err := strconv.Atoi(val)
	if err != nil {
		return def
	}
	return i
}

func startAutoCloseWorker(ctx context.Context, repo *auction.AuctionRepository, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			start := time.Now()
			expired, err := repo.FindExpiredOpen(ctx, 100)
			if err != nil {
				continue
			}
			var closedCount int
			for _, a := range expired {
				if ok, err := repo.CloseIfOpen(ctx, a.Id); err == nil && ok {
					closedCount++
				}
			}
			elapsed := time.Since(start)
			logger.Info("auto-close scan complete")
			_ = elapsed
		}
	}
}
