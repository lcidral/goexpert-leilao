package auction

import (
	"context"
	"fullcycle-auction_go/configuration/logger"
	"fullcycle-auction_go/internal/entity/auction_entity"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// FindExpiredOpen returns up to `limit` auctions that are still Active but with expiration timestamp <= now.
func (ar *AuctionRepository) FindExpiredOpen(ctx context.Context, limit int64) ([]AuctionEntityMongo, error) {
	filter := bson.M{
		"status":    auction_entity.Active,
		"timestamp": bson.M{"$lte": time.Now().Unix()},
	}
	findOpts := options.Find()
	if limit > 0 {
		findOpts.SetLimit(limit)
	}

	cursor, err := ar.Collection.Find(ctx, filter, findOpts)
	if err != nil {
		logger.Error("Error finding expired open auctions", err)
		return nil, err
	}
	defer cursor.Close(ctx)

	var results []AuctionEntityMongo
	if err := cursor.All(ctx, &results); err != nil {
		logger.Error("Error decoding expired open auctions", err)
		return nil, err
	}
	return results, nil
}

// CloseIfOpen performs an atomic update to set status to Completed if it is currently Active.
func (ar *AuctionRepository) CloseIfOpen(ctx context.Context, id string) (bool, error) {
	filter := bson.M{"_id": id, "status": auction_entity.Active}
	update := bson.M{"$set": bson.M{"status": auction_entity.Completed}}
	res, err := ar.Collection.UpdateOne(ctx, filter, update)
	if err != nil {
		logger.Error("Error updating auction to Completed", err)
		return false, err
	}
	return res.ModifiedCount > 0, nil
}
